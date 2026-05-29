# frozen_string_literal: true

require "rails_helper"

RSpec.describe Routing::Commands::GenerateVisitRoutes do
  let(:municipality) { create(:municipality) }
  let(:facility) { create(:health_facility, municipality: municipality) }
  let(:team) { create(:care_team, municipality: municipality, health_facility: facility) }
  let(:membership) { create(:user_municipality_membership, municipality: municipality, scope: "municipality") }

  it "creates ordered visit routes for campaign targets" do
    with_tenant(membership) do
      campaign = create(:home_visit_campaign, municipality: municipality, health_facility: facility, status: "targets_built")
      citizen = create(:citizen, municipality: municipality, health_facility: facility, care_team: team)
      create(
        :campaign_target,
        municipality: municipality,
        health_facility: facility,
        campaign: campaign,
        citizen: citizen
      )

      result = described_class.call(campaign: campaign, route_date: Date.current)

      expect(result.routes_created).to eq(1)
      expect(result.stops_created).to eq(1)
      expect(campaign.visit_routes.first.visit_route_stops.pluck(:stop_order)).to eq([ 1 ])
    end
  end
end
