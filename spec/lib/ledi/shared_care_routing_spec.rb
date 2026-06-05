# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ledi::SharedCareRouting do
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

  it "event_care_team_id prefers case origin then falls back to citizen routing" do
    citizen = with_tenant(tenant_scope) do
      create(:citizen, municipality: municipality, health_facility: facility, care_team: nil, cpf: "52998224725")
    end
    shared_care_case = with_tenant(tenant_scope) do
      SharedCareCase.create!(
        municipality: municipality,
        citizen: citizen,
        origin_care_team_id: nil,
        status: "open"
      )
    end

    expected = CareTeam.where(municipality_id: municipality.id, health_facility_id: facility.id).order(:id).pick(:id)
    expect(described_class.event_care_team_id(shared_care_case)).to eq(expected)
  end
end
