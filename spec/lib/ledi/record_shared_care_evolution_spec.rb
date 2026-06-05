# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ledi::RecordSharedCareEvolution do
  let(:municipality) { create(:municipality) }
  let(:facility_a) { create(:health_facility, municipality: municipality, name: "UBS A") }
  let(:facility_b) { create(:health_facility, municipality: municipality, name: "UBS B") }
  let(:team_a) { create(:care_team, municipality: municipality, health_facility: facility_a) }
  let(:municipal_scope) do
    Cidadaobr::TenantScope.new(
      municipality_id: municipality.id,
      scope: "municipality",
      health_facility_id: nil,
      team_ids: [],
      citizen_id: nil
    )
  end
  let(:facility_b_scope) do
    Cidadaobr::TenantScope.new(
      municipality_id: municipality.id,
      scope: "facility",
      health_facility_id: facility_b.id,
      team_ids: [],
      citizen_id: nil
    )
  end
  let(:citizen) do
    with_tenant(municipal_scope) do
      create(:citizen, municipality: municipality, health_facility: facility_a, care_team: team_a)
    end
  end
  let(:shared_care_case) do
    with_tenant(municipal_scope) do
      Ledi::CreateSharedCareCase.call(citizen_id: citizen.id, ciap2_code: "A01", clinical_summary: "FCC aberta")
    end
  end

  it "records an evolution and emits platform event" do
    evolution = with_tenant(municipal_scope) do
      described_class.call(shared_care_case: shared_care_case, evolution_note: "Evolução registrada")
    end

    expect(evolution).to be_persisted
    expect(evolution.evolution_note).to eq("Evolução registrada")

    with_tenant(municipal_scope) do
      expect(DomainEvent.where(event_type: Cidadaobr::KafkaTopics::SHARED_CARE_EVOLUTION_RECORDED).count).to eq(1)
    end
  end

  it "rejects facility scope when the case belongs to another UBS" do
    expect {
      with_tenant(facility_b_scope) do
        described_class.call(shared_care_case: shared_care_case, evolution_note: "fora do escopo")
      end
    }.to raise_error(ArgumentError, /not accessible in current scope/)
  end
end
