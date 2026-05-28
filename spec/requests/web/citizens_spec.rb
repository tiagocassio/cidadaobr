# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Web citizens", type: :request do
  let(:municipality) { create(:municipality) }
  let(:admin_membership) do
    create(:user_municipality_membership, municipality: municipality, scope: "municipality", role_code: "municipal_admin")
  end

  before { sign_in_web(user: admin_membership.user, membership: admin_membership) }

  it "lists citizens with sanitized search" do
    facility = create(:health_facility, municipality: municipality)
    team = create(:care_team, municipality: municipality, health_facility: facility)

    with_tenant(Cidadaobr::TenantScope.from_membership(admin_membership)) do
      create(:citizen, municipality: municipality, health_facility: facility, care_team: team, full_name: "Maria Silva")
    end

    get web_citizens_path, params: { q: "Maria" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Maria Silva")
  end
end
