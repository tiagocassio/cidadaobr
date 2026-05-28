# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Web micro areas", type: :request do
  let(:municipality) { create(:municipality) }
  let(:facility) { create(:health_facility, municipality: municipality) }
  let(:care_team) { create(:care_team, municipality: municipality, health_facility: facility) }
  let(:admin_membership) do
    create(:user_municipality_membership, municipality: municipality, scope: "municipality", role_code: "municipal_admin")
  end

  before { sign_in_web(user: admin_membership.user, membership: admin_membership) }

  it "creates micro area with facility coverage links" do
    post web_micro_areas_path, params: {
      micro_area: {
        code: "01",
        name: "Centro",
        care_team_id: care_team.id,
        coverage_sw_lat: -23.58,
        coverage_sw_lng: -46.65,
        coverage_ne_lat: -23.52,
        coverage_ne_lng: -46.61,
        health_facility_ids: [ facility.id ]
      }
    }

    expect(response).to redirect_to(web_micro_areas_path)

    with_tenant(Cidadaobr::TenantScope.from_membership(admin_membership)) do
      area = MicroArea.find_by!(code: "01")
      expect(area.health_facilities).to contain_exactly(facility)
    end
  end
end
