# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Web care teams", type: :request do
  let(:municipality) { create(:municipality) }
  let(:facility_a) { create(:health_facility, municipality: municipality, name: "UBS A") }
  let(:facility_b) { create(:health_facility, municipality: municipality, name: "UBS B") }
  let(:admin_membership) do
    create(:user_municipality_membership, municipality: municipality, scope: "municipality")
  end
  let(:facility_membership) do
    create(:user_municipality_membership, user: create(:user), municipality: municipality, health_facility: facility_a, scope: "facility")
  end
  let!(:team_b) { create(:care_team, municipality: municipality, health_facility: facility_b) }

  it "scopes facility manager to own UBS teams" do
    sign_in_web(user: facility_membership.user, membership: facility_membership)

    get web_care_teams_path
    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include(team_b.ine)
  end

  it "allows municipal admin to see all teams" do
    sign_in_web(user: admin_membership.user, membership: admin_membership)

    get web_care_teams_path
    expect(response.body).to include(team_b.ine)
    expect(response.body).to include(facility_b.name)
  end

  it "blocks team-scoped users from creating teams" do
    team = create(:care_team, municipality: municipality, health_facility: facility_a)
    team_user = create(:user)
    create(:user_team_assignment, user: team_user, care_team: team)
    team_membership = create(
      :user_municipality_membership,
      user: team_user,
      municipality: municipality,
      scope: "team",
      role_code: "community_agent"
    )

    sign_in_web(user: team_user, membership: team_membership)

    get new_web_care_team_path
    expect(response).to redirect_to(web_root_path)

    expect {
      post web_care_teams_path, params: {
        care_team: { name: "Equipe Nova", ine: "0009998888", health_facility_id: facility_a.id }
      }
    }.not_to change(CareTeam, :count)
  end

  it "includes citizens linked only via care team for facility managers" do
    team = create(:care_team, municipality: municipality, health_facility: facility_a)
    citizen = with_tenant(admin_membership) do
      create(:citizen, municipality: municipality, care_team: team, health_facility: nil, cpf: "39053344705")
    end

    sign_in_web(user: facility_membership.user, membership: facility_membership)

    get web_citizens_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(citizen.cpf)
  end
end
