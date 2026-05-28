# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Web citizens", type: :request do
  let(:municipality) { create(:municipality) }
  let(:facility) { create(:health_facility, municipality: municipality) }
  let(:team) { create(:care_team, municipality: municipality, health_facility: facility) }
  let(:admin_membership) do
    create(:user_municipality_membership, municipality: municipality, scope: "municipality", role_code: "municipal_admin")
  end

  before { sign_in_web(user: admin_membership.user, membership: admin_membership) }

  it "lists citizens with sanitized search" do
    with_tenant(Cidadaobr::TenantScope.from_membership(admin_membership)) do
      create(:citizen, municipality: municipality, health_facility: facility, care_team: team, full_name: "Maria Silva")
    end

    get web_citizens_path, params: { q: "Maria" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Maria Silva")
  end

  it "creates a citizen" do
    expect {
      post web_citizens_path, params: {
        citizen: {
          full_name: "João Souza",
          cpf: "39053344705",
          health_facility_id: facility.id,
          care_team_id: team.id
        }
      }
    }.to change { with_tenant(admin_membership) { Citizen.count } }.by(1)

    citizen = with_tenant(admin_membership) { Citizen.order(:created_at).last }
    expect(response).to redirect_to(web_citizen_path(citizen))
  end

  it "updates a citizen" do
    citizen = with_tenant(admin_membership) do
      create(:citizen, municipality: municipality, health_facility: facility, care_team: team, full_name: "Ana")
    end

    patch web_citizen_path(citizen), params: { citizen: { full_name: "Ana Costa" } }

    expect(response).to redirect_to(web_citizen_path(citizen))
    expect(with_tenant(admin_membership) { citizen.reload.full_name }).to eq("Ana Costa")
  end

  it "links citizen to household" do
    citizen = with_tenant(admin_membership) { create(:citizen, municipality: municipality, health_facility: facility, care_team: team) }
    household = with_tenant(admin_membership) { create(:household, municipality: municipality, health_facility: facility, care_team: team) }

    expect {
      post web_citizen_household_members_path(citizen), params: { household_member: { household_id: household.id } }
    }.to change { with_tenant(admin_membership) { HouseholdMember.count } }.by(1)

    expect(response).to redirect_to(web_citizen_path(citizen))
  end
end
