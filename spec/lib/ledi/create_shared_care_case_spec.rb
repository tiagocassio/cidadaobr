# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ledi::CreateSharedCareCase do
  let(:municipality) { create(:municipality) }
  let(:facility) { create(:health_facility, municipality: municipality) }
  let!(:team) { create(:care_team, municipality: municipality, health_facility: facility) }
  let(:tenant_scope) do
    Cidadaobr::TenantScope.new(
      municipality_id: municipality.id,
      scope: "municipality",
      health_facility_id: nil,
      team_ids: [],
      citizen_id: nil
    )
  end
  let(:citizen) do
    with_tenant(tenant_scope) do
      create(:citizen, municipality: municipality, health_facility: facility, care_team: team)
    end
  end

  it "creates a shared care case and emits platform event" do
    shared_care_case = with_tenant(tenant_scope) do
      described_class.call(citizen_id: citizen.id, ciap2_code: "A01", clinical_summary: "FCC aberta")
    end

    expect(shared_care_case).to be_persisted
    expect(shared_care_case.origin_care_team_id).to eq(team.id)

    with_tenant(tenant_scope) do
      expect(DomainEvent.where(event_type: Cidadaobr::KafkaTopics::SHARED_CARE_CASE_CREATED).count).to eq(1)
    end
  end

  it "resolves origin care team from UBS when citizen has no direct team" do
    citizen_without_team = with_tenant(tenant_scope) do
      create(:citizen, municipality: municipality, health_facility: facility, care_team: nil, cpf: "39053344705")
    end

    shared_care_case = with_tenant(tenant_scope) do
      described_class.call(citizen_id: citizen_without_team.id, ciap2_code: "A01", clinical_summary: "FCC sem equipe")
    end

    expected_team_id = CareTeam.where(municipality_id: municipality.id, health_facility_id: facility.id).order(:id).pick(:id)
    expect(shared_care_case.origin_care_team_id).to eq(expected_team_id)
  end

  it "rejects explicit origin care team outside tenant scope" do
    facility_b = create(:health_facility, municipality: municipality, name: "UBS B")
    team_b = create(:care_team, municipality: municipality, health_facility: facility_b)
    facility_scope = Cidadaobr::TenantScope.new(
      municipality_id: municipality.id,
      scope: "facility",
      health_facility_id: facility.id,
      team_ids: [],
      citizen_id: nil
    )

    expect {
      with_tenant(facility_scope) do
        described_class.call(
          citizen_id: citizen.id,
          origin_care_team_id: team_b.id,
          ciap2_code: "A01",
          clinical_summary: "equipe fora do escopo"
        )
      end
    }.to raise_error(ArgumentError, /origin care team not accessible in current scope/)
  end

  it "rejects facility scope when citizen belongs to another UBS" do
    facility_b = create(:health_facility, municipality: municipality, name: "UBS B")
    facility_scope = Cidadaobr::TenantScope.new(
      municipality_id: municipality.id,
      scope: "facility",
      health_facility_id: facility_b.id,
      team_ids: [],
      citizen_id: nil
    )

    expect {
      with_tenant(facility_scope) do
        described_class.call(citizen_id: citizen.id, ciap2_code: "A01", clinical_summary: "fora do escopo")
      end
    }.to raise_error(ArgumentError, /not accessible in current scope/)
  end
end
