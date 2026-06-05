# frozen_string_literal: true

require "rails_helper"

RSpec.describe CitizenPortal::CareTeamRouting do
  let(:municipality) { create(:municipality) }
  let(:facility) { create(:health_facility, municipality: municipality) }
  let!(:team_a) { create(:care_team, municipality: municipality, health_facility: facility, ine: "0000000001") }
  let!(:team_b) { create(:care_team, municipality: municipality, health_facility: facility, ine: "0000000002") }
  let(:tenant_scope) do
    Cidadaobr::TenantScope.new(
      municipality_id: municipality.id,
      scope: "municipality",
      health_facility_id: nil,
      team_ids: [],
      citizen_id: nil
    )
  end

  it "returns the citizen care team when assigned" do
    citizen = with_tenant(tenant_scope) do
      create(:citizen, municipality: municipality, health_facility: facility, care_team: team_b)
    end

    expect(described_class.resolve_care_team_id(citizen)).to eq(team_b.id)
  end

  it "falls back to the first team at the citizen UBS when care team is missing" do
    citizen = with_tenant(tenant_scope) do
      create(:citizen, municipality: municipality, health_facility: facility, care_team: nil)
    end

    expected = CareTeam.where(municipality_id: municipality.id, health_facility_id: facility.id).order(:id).pick(:id)
    expect(described_class.resolve_care_team_id(citizen)).to eq(expected)
  end

  it "returns nil when citizen has no care team and no health facility" do
    citizen = with_tenant(tenant_scope) do
      create(:citizen, municipality: municipality, health_facility: nil, care_team: nil, cpf: "39053344705")
    end

    expect(described_class.resolve_care_team_id(citizen)).to be_nil
  end

end
