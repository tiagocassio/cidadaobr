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

      expect(result.skipped).to be(false)
      expect(result.routes_created).to eq(1)
      expect(result.stops_created).to eq(1)
      expect(campaign.visit_routes.first.visit_route_stops.pluck(:stop_order)).to eq([ 1 ])
    end
  end

  it "does not create duplicate routes for the same date" do
    with_tenant(membership) do
      campaign = create(:home_visit_campaign, municipality: municipality, health_facility: facility, status: "targets_built")
      citizen = create(:citizen, municipality: municipality, health_facility: facility, care_team: team)
      create(:campaign_target, municipality: municipality, health_facility: facility, campaign: campaign, citizen: citizen)

      first = described_class.call(campaign: campaign, route_date: Date.current)
      second = described_class.call(campaign: campaign, route_date: Date.current)

      expect(first.routes_created).to eq(1)
      expect(second.skipped).to be(true)
      expect(second.routes_created).to eq(0)
      expect(campaign.visit_routes.where(route_date: Date.current).count).to eq(1)
    end
  end

  it "reports unassigned targets without routing them" do
    with_tenant(membership) do
      campaign = create(:home_visit_campaign, municipality: municipality, health_facility: facility, status: "targets_built")
      assigned = create(:citizen, municipality: municipality, health_facility: facility, care_team: team)
      unassigned = create(:citizen, municipality: municipality, health_facility: facility, care_team: nil)
      create(:campaign_target, municipality: municipality, health_facility: facility, campaign: campaign, citizen: assigned)
      create(:campaign_target, municipality: municipality, health_facility: facility, campaign: campaign, citizen: unassigned)

      result = described_class.call(campaign: campaign, route_date: Date.current)

      expect(result.unassigned_count).to eq(1)
      expect(result.stops_created).to eq(1)
    end
  end
end
