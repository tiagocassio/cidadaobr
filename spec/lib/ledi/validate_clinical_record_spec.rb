# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ledi::ValidateClinicalRecord do
  let(:municipality) { create(:municipality, ibge_code: "3550308") }
  let(:facility) { create(:health_facility, municipality: municipality, cnes: "2000001") }
  let(:membership) do
    create(:user_municipality_membership, municipality: municipality, health_facility: facility, scope: "facility")
  end

  before do
    load Rails.root.join("db/seeds/ledi_catalog.rb")
  end

  def import_fci!
    with_tenant(membership) do
      Ledi::ImportTransportRecord.call(
        payload_binary: LediFixtures.fci_binary(cnes: facility.cnes, ibge: municipality.ibge_code)
      )[:clinical_record]
    end
  end

  it "marks record valid and emits validated and persisted events" do
    clinical_record = import_fci!

    result = with_tenant(membership) do
      validation_result = described_class.call(clinical_record_id: clinical_record.id)
      record = clinical_record.reload

      expect(validation_result.valid).to be(true)
      expect(record.validation_status).to eq("valid")
      expect(record.transport_record.status).to eq("validated")
      expect(DomainEvent.where(event_type: Cidadaobr::KafkaTopics::CLINICAL_RECORD_VALIDATED).count).to eq(1)
      expect(DomainEvent.where(event_type: Cidadaobr::KafkaTopics::CLINICAL_RECORD_PERSISTED).count).to eq(1)
      validation_result
    end

    expect(result.valid).to be(true)
  end

  it "propagates care_team_id on validated and persisted domain events" do
    care_team = create(:care_team, municipality: municipality, health_facility: facility, ine: "0000000001")
    clinical_record = import_fci!

    with_tenant(membership) do
      clinical_record.update!(care_team_id: care_team.id)
      described_class.call(clinical_record_id: clinical_record.id)
    end

    validated = with_tenant(membership) do
      DomainEvent.find_by!(event_type: Cidadaobr::KafkaTopics::CLINICAL_RECORD_VALIDATED, aggregate_id: clinical_record.id)
    end
    persisted = with_tenant(membership) do
      DomainEvent.find_by!(event_type: Cidadaobr::KafkaTopics::CLINICAL_RECORD_PERSISTED, aggregate_id: clinical_record.id)
    end

    expect(validated.care_team_id).to eq(care_team.id)
    expect(persisted.care_team_id).to eq(care_team.id)
  end

  it "emits validation_failed when rules fail" do
    clinical_record = import_fci!

    result = with_tenant(membership) do
      clinical_record.update!(payload_json: clinical_record.payload_json.merge("tp_cds_origem" => 1))
      validation_result = described_class.call(clinical_record_id: clinical_record.id)
      record = clinical_record.reload

      expect(validation_result.valid).to be(false)
      expect(record.validation_status).to eq("invalid")
      expect(record.validation_errors).not_to be_empty
      expect(record.transport_record.status).to eq("draft")
      expect(DomainEvent.where(event_type: Cidadaobr::KafkaTopics::CLINICAL_RECORD_VALIDATION_FAILED).count).to eq(1)
      validation_result
    end

    expect(result.valid).to be(false)
  end
end
