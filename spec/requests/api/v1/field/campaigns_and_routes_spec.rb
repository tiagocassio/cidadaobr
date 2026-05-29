# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api field campaigns and routes", type: :request do
  let(:municipality) { create(:municipality) }
  let(:facility) { create(:health_facility, municipality: municipality) }
  let(:team) { create(:care_team, municipality: municipality, health_facility: facility) }
  let(:membership) do
    create(
      :user_municipality_membership,
      municipality: municipality,
      health_facility: facility,
      scope: "team",
      role_code: "community_agent"
    )
  end
  let(:headers) { auth_headers_for(membership) }

  before do
    create(:user_team_assignment, user: membership.user, care_team: team)
  end

  it "lists active home visit campaigns" do
    with_tenant(membership) do
      create(:home_visit_campaign, municipality: municipality, health_facility: facility, status: "active")
    end

    get api_v1_field_campaigns_path, headers: headers

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.size).to eq(1)
  end

  it "does not list campaigns still in routes_generated" do
    with_tenant(membership) do
      create(:home_visit_campaign, municipality: municipality, health_facility: facility, status: "routes_generated")
    end

    get api_v1_field_campaigns_path, headers: headers

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to be_empty
  end

  it "lists scheduled campaigns after routes are published" do
    with_tenant(membership) do
      create(:home_visit_campaign, municipality: municipality, health_facility: facility, status: "scheduled")
    end

    get api_v1_field_campaigns_path, headers: headers

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.size).to eq(1)
  end

  it "shows published visit route with ordered stops" do
    campaign = nil
    route = nil
    with_tenant(membership) do
      campaign = create(:home_visit_campaign, municipality: municipality, health_facility: facility, status: "scheduled")
      citizen = create(:citizen, municipality: municipality, health_facility: facility, care_team: team)
      route = create(
        :visit_route,
        municipality: municipality,
        health_facility: facility,
        home_visit_campaign: campaign,
        care_team: team,
        status: "published"
      )
      create(:visit_route_stop, municipality: municipality, visit_route: route, citizen: citizen, stop_order: 1)
    end

    get api_v1_field_visit_route_path(route), headers: headers

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["stops"].size).to eq(1)
  end

  it "does not expose draft visit routes" do
    route = nil
    with_tenant(membership) do
      campaign = create(:home_visit_campaign, municipality: municipality, health_facility: facility, status: "routes_generated")
      route = create(
        :visit_route,
        municipality: municipality,
        health_facility: facility,
        home_visit_campaign: campaign,
        care_team: team,
        status: "draft"
      )
    end

    get api_v1_field_visit_route_path(route), headers: headers

    expect(response).to have_http_status(:not_found)
  end
end
