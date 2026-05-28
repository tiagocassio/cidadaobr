# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Web health facilities", type: :request do
  let(:municipality) { create(:municipality) }
  let(:admin_membership) do
    create(:user_municipality_membership, municipality: municipality, scope: "municipality", role_code: "municipal_admin")
  end
  let(:facility) { create(:health_facility, municipality: municipality) }
  let(:facility_membership) do
    create(:user_municipality_membership, user: create(:user), municipality: municipality, health_facility: facility, scope: "facility")
  end

  it "allows municipal admin to list and create facilities" do
    sign_in_web(user: admin_membership.user, membership: admin_membership)

    get web_health_facilities_path
    expect(response).to have_http_status(:ok)

    expect {
      post web_health_facilities_path, params: {
        health_facility: { name: "UBS Teste", cnes: "7654321", facility_service_kind: "primary_care" }
      }
    }.to change(HealthFacility, :count).by(1)
  end

  it "blocks facility manager from managing facilities" do
    sign_in_web(user: facility_membership.user, membership: facility_membership)

    get web_health_facilities_path
    expect(response).to redirect_to(web_root_path)
  end

  it "allows municipal admin to view a facility" do
    sign_in_web(user: admin_membership.user, membership: admin_membership)

    get web_health_facility_path(facility)

    expect(response).to have_http_status(:ok)
  end
end
