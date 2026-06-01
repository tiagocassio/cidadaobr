# frozen_string_literal: true

require "rails_helper"

RSpec.describe Routing::Commands::ClearVisitRoutes do
  let(:municipality) { create(:municipality) }
  let(:facility) do
    create(
      :health_facility,
      municipality: municipality,
      location: Cidadaobr::GeoPoint.build(lng: -46.6333, lat: -23.5505)
    )
  end
  let(:team) { create(:care_team, municipality: municipality, health_facility: facility) }
  let(:membership) { create(:user_municipality_membership, municipality: municipality, scope: "municipality") }

  it "removes routes and resets routed targets" do
    with_tenant(membership) do
      campaign = create(:home_visit_campaign, municipality: municipality, health_facility: facility, status: "routes_generated")
      citizen = create(:citizen, municipality: municipality, health_facility: facility, care_team: team)
      target = create(
        :campaign_target,
        municipality: municipality,
        health_facility: facility,
        campaign: campaign,
        citizen: citizen,
        status: "routed"
      )
      route = create(
        :visit_route,
        municipality: municipality,
        health_facility: facility,
        home_visit_campaign: campaign,
        care_team: team,
        route_date: Date.current,
        status: "draft"
      )
      create(
        :visit_route_stop,
        municipality: municipality,
        visit_route: route,
        citizen: citizen,
        campaign_target: target,
        stop_order: 1
      )

      result = described_class.call(campaign: campaign, route_date: Date.current)

      expect(result.routes_removed).to eq(1)
      expect(campaign.visit_routes.count).to eq(0)
      expect(campaign.home_visit_campaign_provisioning).to be_nil
      expect(target.reload.status).to eq("pending")
      expect(campaign.reload.status).to eq("targets_built")
    end
  end

  it "blocks clearing routes when provisioning was dispatched" do
    with_tenant(membership) do
      campaign = create(:home_visit_campaign, municipality: municipality, health_facility: facility, status: "routes_generated")
      route = create(
        :visit_route,
        municipality: municipality,
        health_facility: facility,
        home_visit_campaign: campaign,
        care_team: team,
        route_date: Date.current,
        status: "published"
      )
      VisitRouteProvisioning.create!(
        municipality: municipality,
        health_facility: facility,
        visit_route: route,
        status: "dispatched",
        lines_json: []
      )

      result = described_class.call(campaign: campaign, route_date: Date.current)

      expect(result.routes_removed).to eq(0)
      expect(result.message).to be_present
      expect(campaign.visit_routes.count).to eq(1)
    end
  end
end

RSpec.describe Routing::Commands::PublishVisitRoutes do
  let(:municipality) { create(:municipality) }
  let(:facility) do
    create(
      :health_facility,
      municipality: municipality,
      location: Cidadaobr::GeoPoint.build(lng: -46.6333, lat: -23.5505)
    )
  end
  let(:team) { create(:care_team, municipality: municipality, health_facility: facility) }
  let(:membership) { create(:user_municipality_membership, municipality: municipality, scope: "municipality") }

  it "publishes draft routes and schedules the campaign" do
    with_tenant(membership) do
      product = create(:immunobiological_product, municipality: municipality)
      create(
        :immunobiological_lot,
        municipality: municipality,
        health_facility: facility,
        immunobiological_product: product,
        quantity_on_hand: 100
      )
      campaign = create(
        :home_visit_campaign,
        municipality: municipality,
        health_facility: facility,
        status: "routes_generated",
        target_audience_definition: { "immunobiological_product_id" => product.id }
      )
      route = create(
        :visit_route,
        municipality: municipality,
        health_facility: facility,
        home_visit_campaign: campaign,
        care_team: team,
        route_date: Date.current,
        status: "draft"
      )
      VisitRouteProvisioning.create!(
        municipality: municipality,
        health_facility: facility,
        visit_route: route,
        status: "calculated",
        lines_json: [
          {
            "key" => "immunobiological",
            "label" => product.name,
            "quantity_required" => 1,
            "unit" => "dose",
            "immunobiological_product_id" => product.id
          }
        ]
      )
      HomeVisitCampaignProvisioning.create!(
        municipality: municipality,
        health_facility: facility,
        home_visit_campaign: campaign,
        status: "calculated",
        totals_json: []
      )
      Inventory::Commands::ReserveVisitRouteSupplies.call(campaign: campaign)

      result = described_class.call(campaign: campaign, route_date: Date.current)

      expect(result.routes_published).to eq(1)
      expect(route.reload.status).to eq("published")
      expect(campaign.reload.status).to eq("scheduled")
    end
  end

  it "blocks publish when provisioning is blocked" do
    with_tenant(membership) do
      product = create(:immunobiological_product, municipality: municipality)
      campaign = create(
        :home_visit_campaign,
        municipality: municipality,
        health_facility: facility,
        status: "routes_generated",
        target_audience_definition: { "immunobiological_product_id" => product.id }
      )
      citizen = create(:citizen, municipality: municipality, health_facility: facility, care_team: team)
      create(
        :campaign_target,
        municipality: municipality,
        health_facility: facility,
        campaign: campaign,
        citizen: citizen
      )
      Routing::Commands::GenerateVisitRoutes.call(campaign: campaign, route_date: Date.current)
      route = campaign.visit_routes.first

      expect(campaign.home_visit_campaign_provisioning.status).to eq("blocked")

      result = described_class.call(campaign: campaign, route_date: Date.current)

      expect(result.routes_published).to eq(0)
      expect(result.message).to be_present
      expect(route.reload.status).to eq("draft")
    end
  end

  it "requires reserved provisioning before publish" do
    with_tenant(membership) do
      campaign = create(:home_visit_campaign, municipality: municipality, health_facility: facility, status: "routes_generated")
      create(
        :visit_route,
        municipality: municipality,
        health_facility: facility,
        home_visit_campaign: campaign,
        care_team: team,
        route_date: Date.current,
        status: "draft"
      )
      HomeVisitCampaignProvisioning.create!(
        municipality: municipality,
        health_facility: facility,
        home_visit_campaign: campaign,
        status: "calculated",
        totals_json: []
      )

      result = described_class.call(campaign: campaign, route_date: Date.current)

      expect(result.routes_published).to eq(0)
      expect(result.message).to be_present
      expect(campaign.reload.home_visit_campaign_provisioning.status).to eq("calculated")
    end
  end
end
