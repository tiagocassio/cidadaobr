# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ledi::SubmitLediBatch do
  let(:municipality) { create(:municipality, ibge_code: "3550308") }
  let(:facility) { create(:health_facility, municipality: municipality, cnes: "2000001") }
  let(:membership) do
    create(:user_municipality_membership, municipality: municipality, health_facility: facility, scope: "facility")
  end

  before do
    load Rails.root.join("db/seeds/ledi_catalog.rb")
  end

  def import_and_validate!
    with_tenant(membership) do
      clinical_record = Ledi::ImportTransportRecord.call(
        payload_binary: LediFixtures.fci_binary(cnes: facility.cnes, ibge: municipality.ibge_code)
      )[:clinical_record]
      Ledi::ValidateClinicalRecord.call(clinical_record_id: clinical_record.id)
    end
  end

  it "groups validated transport records into a ready batch" do
    import_and_validate!

    batch = with_tenant(membership) do
      created_batch = described_class.call

      expect(created_batch.status).to eq("ready")
      expect(TransportRecord.where(ledi_batch_id: created_batch.id).count).to eq(1)
      expect(DomainEvent.where(event_type: Cidadaobr::KafkaTopics::LEDI_BATCH_SUBMITTED).count).to eq(1)
      expect(OutboxMessage.find_by(event_type: Cidadaobr::KafkaTopics::LEDI_BATCH_SUBMITTED).topic).to eq(Cidadaobr::KafkaTopics::LEDI_BATCH_SUBMITTED)
      created_batch
    end

    expect(batch).to be_persisted
  end

  it "raises when no validated transport records are available" do
    expect do
      with_tenant(membership) { described_class.call }
    end.to raise_error(Ledi::Errors::EmptyBatchError)
  end

  it "scopes batch submission to the current facility" do
    other_facility = create(:health_facility, municipality: municipality, cnes: "2000002", name: "UBS B")
    other_membership = create(
      :user_municipality_membership,
      municipality: municipality,
      health_facility: other_facility,
      scope: "facility"
    )

    import_and_validate!

    with_tenant(other_membership) do
      expect do
        described_class.call
      end.to raise_error(Ledi::Errors::EmptyBatchError)
    end

    batch = with_tenant(membership) { described_class.call }

    expect(batch.health_facility_id).to eq(facility.id)
  end

  it "scopes batch submission to the current care team" do
    care_team = create(:care_team, municipality: municipality, health_facility: facility, ine: "3000000100")
    other_team = create(:care_team, municipality: municipality, health_facility: facility, ine: "3000000101")
    user = create(:user)
    create(:user_team_assignment, user: user, care_team: care_team)
    team_membership = create(
      :user_municipality_membership,
      user: user,
      municipality: municipality,
      scope: "team"
    )

    with_tenant(membership) do
      clinical_record = Ledi::ImportTransportRecord.call(
        payload_binary: LediFixtures.fci_binary(
          cnes: facility.cnes,
          ibge: municipality.ibge_code,
          ine: care_team.ine
        )
      )[:clinical_record]
      Ledi::ValidateClinicalRecord.call(clinical_record_id: clinical_record.id)

      other_clinical = Ledi::ImportTransportRecord.call(
        payload_binary: LediFixtures.fci_binary(
          cnes: facility.cnes,
          ibge: municipality.ibge_code,
          ine: other_team.ine,
          cpf: "52998224725"
        )
      )[:clinical_record]
      Ledi::ValidateClinicalRecord.call(clinical_record_id: other_clinical.id)
    end

    with_tenant(team_membership) do
      batch = described_class.call
      expect(batch.care_team_id).to eq(care_team.id)
      expect(TransportRecord.where(ledi_batch_id: batch.id).pluck(:care_team_id)).to all(eq(care_team.id))
    end

    with_tenant(team_membership) do
      expect do
        described_class.call
      end.to raise_error(Ledi::Errors::EmptyBatchError)
    end

    with_tenant(membership) do
      expect(
        TransportRecord.where(care_team_id: other_team.id, ledi_batch_id: nil, status: "validated").count
      ).to eq(1)
    end
  end

  it "raises when team scope membership spans multiple care teams" do
    user = create(:user)
    team_a = create(:care_team, municipality: municipality, health_facility: facility, ine: "3000000200")
    team_b = create(:care_team, municipality: municipality, health_facility: facility, ine: "3000000201")
    create(:user_team_assignment, user: user, care_team: team_a)
    create(:user_team_assignment, user: user, care_team: team_b)
    team_membership = create(
      :user_municipality_membership,
      user: user,
      municipality: municipality,
      scope: "team"
    )

    expect do
      with_tenant(team_membership) { described_class.call }
    end.to raise_error(Ledi::Errors::AmbiguousTeamScopeError)
  end

  it "keeps municipal batch numbers unique when facility and team ids are null" do
    isolated_municipality = create(:municipality, ibge_code: "8887776")
    isolated_facility = create(:health_facility, municipality: isolated_municipality, cnes: "3000001")
    municipal_membership = create(:user_municipality_membership, municipality: isolated_municipality, scope: "municipality")

    import_and_validate_municipal = lambda do |cpf|
      with_tenant(municipal_membership) do
        clinical_record = Ledi::ImportTransportRecord.call(
          payload_binary: LediFixtures.fci_binary(cnes: isolated_facility.cnes, ibge: isolated_municipality.ibge_code, cpf: cpf)
        )[:clinical_record]
        Ledi::ValidateClinicalRecord.call(clinical_record_id: clinical_record.id)
      end
    end

    import_and_validate_municipal.call("39053344705")

    with_tenant(municipal_membership) do
      described_class.call
    end

    import_and_validate_municipal.call("52998224725")

    expect do
      with_tenant(municipal_membership) { described_class.call }
    end.not_to raise_error

    batch_numbers = with_tenant(municipal_membership) { LediBatch.pluck(:batch_number) }
    expect(batch_numbers).to eq([ 1, 2 ])
  end
end
