# frozen_string_literal: true

require "rails_helper"

RSpec.describe Inventory::Commands::ReserveVisitRouteSupplies do
  let(:municipality) { create(:municipality) }
  let(:facility) { create(:health_facility, municipality: municipality) }
  let(:product) { create(:immunobiological_product, municipality: municipality) }
  let(:care_team) { create(:care_team, municipality: municipality, health_facility: facility) }
  let(:membership) { create(:user_municipality_membership, municipality: municipality, scope: "municipality") }

  it "reserves doses FEFO and marks provisioning as reserved" do
    with_tenant(membership) do
      lot_near = create(
        :immunobiological_lot,
        municipality: municipality,
        health_facility: facility,
        immunobiological_product: product,
        quantity_on_hand: 3,
        expires_on: 1.month.from_now.to_date
      )
      lot_far = create(
        :immunobiological_lot,
        municipality: municipality,
        health_facility: facility,
        immunobiological_product: product,
        quantity_on_hand: 10,
        expires_on: 1.year.from_now.to_date,
        lot_number: "LOT-FAR"
      )

      campaign = create(
        :home_visit_campaign,
        municipality: municipality,
        health_facility: facility,
        target_audience_definition: { "immunobiological_product_id" => product.id }
      )
      route = create(:visit_route, home_visit_campaign: campaign, care_team: care_team, municipality: municipality, health_facility: facility)
      VisitRouteProvisioning.create!(
        municipality: municipality,
        health_facility: facility,
        visit_route: route,
        status: "calculated",
        lines_json: [
          {
            "key" => "immunobiological",
            "label" => product.name,
            "quantity_required" => 5,
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

      result = described_class.call(campaign: campaign)

      expect(result.blocked).to be(false)
      expect(result.routes_reserved).to eq(1)
      expect(route.visit_route_provisioning.reload.status).to eq("reserved")
      expect(lot_near.reload.quantity_on_hand).to eq(0)
      expect(lot_far.reload.quantity_on_hand).to eq(8)
      expect(StockMovement.where(movement_type: "reserve").sum(:quantity)).to eq(5)
      expect(campaign.home_visit_campaign_provisioning.reload.status).to eq("reserved")
    end
  end

  it "records visit_route.supplies.reserved platform event" do
    with_tenant(membership) do
      create(
        :immunobiological_lot,
        municipality: municipality,
        health_facility: facility,
        immunobiological_product: product,
        quantity_on_hand: 10,
        expires_on: 1.year.from_now.to_date
      )
      campaign = create(
        :home_visit_campaign,
        municipality: municipality,
        health_facility: facility,
        target_audience_definition: { "immunobiological_product_id" => product.id }
      )
      route = create(:visit_route, home_visit_campaign: campaign, care_team: care_team, municipality: municipality, health_facility: facility)
      VisitRouteProvisioning.create!(
        municipality: municipality,
        health_facility: facility,
        visit_route: route,
        status: "calculated",
        lines_json: [
          {
            "key" => "immunobiological",
            "label" => product.name,
            "quantity_required" => 2,
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

      expect {
        described_class.call(campaign: campaign)
      }.to change(DomainEvent, :count).by(1)

      expect(DomainEvent.order(:created_at).last.event_type).to eq(Cidadaobr::KafkaTopics::VISIT_ROUTE_SUPPLIES_RESERVED)
    end
  end

  it "releases reserved stock when routes are cleared" do
    with_tenant(membership) do
      lot = create(
        :immunobiological_lot,
        municipality: municipality,
        health_facility: facility,
        immunobiological_product: product,
        quantity_on_hand: 10
      )
      campaign = create(:home_visit_campaign, municipality: municipality, health_facility: facility,
                        target_audience_definition: { "immunobiological_product_id" => product.id })
      route = create(:visit_route, home_visit_campaign: campaign, care_team: care_team, municipality: municipality, health_facility: facility)
      provisioning = VisitRouteProvisioning.create!(
        municipality: municipality,
        health_facility: facility,
        visit_route: route,
        status: "calculated",
        lines_json: [
          {
            "key" => "immunobiological",
            "label" => product.name,
            "quantity_required" => 4,
            "unit" => "dose",
            "immunobiological_product_id" => product.id
          }
        ]
      )
      described_class.call(campaign: campaign)
      expect(lot.reload.quantity_on_hand).to eq(6)

      Routing::Commands::ClearVisitRoutes.call(campaign: campaign, route_date: route.route_date)

      expect(lot.reload.quantity_on_hand).to eq(10)
      expect(StockMovement.where(movement_type: "reserve")).to be_empty
      expect { provisioning.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  it "rolls back partial reservations when any route is blocked" do
    with_tenant(membership) do
      lot = create(
        :immunobiological_lot,
        municipality: municipality,
        health_facility: facility,
        immunobiological_product: product,
        quantity_on_hand: 10
      )
      campaign = create(
        :home_visit_campaign,
        municipality: municipality,
        health_facility: facility,
        target_audience_definition: { "immunobiological_product_id" => product.id }
      )
      ok_route = create(:visit_route, home_visit_campaign: campaign, care_team: care_team, municipality: municipality, health_facility: facility, sequence_number: 1)
      short_route = create(:visit_route, home_visit_campaign: campaign, care_team: care_team, municipality: municipality, health_facility: facility, sequence_number: 2)
      VisitRouteProvisioning.create!(
        municipality: municipality,
        health_facility: facility,
        visit_route: ok_route,
        status: "calculated",
        lines_json: [
          {
            "key" => "immunobiological",
            "label" => product.name,
            "quantity_required" => 4,
            "unit" => "dose",
            "immunobiological_product_id" => product.id
          }
        ]
      )
      VisitRouteProvisioning.create!(
        municipality: municipality,
        health_facility: facility,
        visit_route: short_route,
        status: "calculated",
        lines_json: [
          {
            "key" => "immunobiological",
            "label" => product.name,
            "quantity_required" => 10,
            "unit" => "dose",
            "immunobiological_product_id" => product.id
          }
        ]
      )

      result = described_class.call(campaign: campaign)

      expect(result.blocked).to be(true)
      expect(result.routes_reserved).to eq(0)
      expect(lot.reload.quantity_on_hand).to eq(10)
      expect(ok_route.visit_route_provisioning.reload.status).to eq("calculated")
      expect(short_route.visit_route_provisioning.reload.status).to eq("calculated")
      expect(StockMovement.where(movement_type: "reserve")).to be_empty
    end
  end

  it "blocks reserve when supply line has no resolvable code" do
    with_tenant(membership) do
      campaign = create(:home_visit_campaign, municipality: municipality, health_facility: facility)
      route = create(:visit_route, home_visit_campaign: campaign, care_team: care_team, municipality: municipality, health_facility: facility)
      VisitRouteProvisioning.create!(
        municipality: municipality,
        health_facility: facility,
        visit_route: route,
        status: "calculated",
        lines_json: [
          {
            "label" => "Mystery item",
            "quantity_required" => 2,
            "unit" => "unit"
          }
        ]
      )

      result = described_class.call(campaign: campaign)

      expect(result.blocked).to be(true)
      expect(result.shortages).to include(/missing supply item code/)
      expect(route.visit_route_provisioning.reload.status).to eq("calculated")
    end
  end

  it "reserves all route dates when route_date is omitted" do
    with_tenant(membership) do
      lot = create(
        :immunobiological_lot,
        municipality: municipality,
        health_facility: facility,
        immunobiological_product: product,
        quantity_on_hand: 20
      )
      campaign = create(
        :home_visit_campaign,
        municipality: municipality,
        health_facility: facility,
        target_audience_definition: { "immunobiological_product_id" => product.id }
      )
      today_route = create(
        :visit_route,
        home_visit_campaign: campaign,
        care_team: care_team,
        municipality: municipality,
        health_facility: facility,
        route_date: Date.current,
        sequence_number: 1
      )
      tomorrow_route = create(
        :visit_route,
        home_visit_campaign: campaign,
        care_team: care_team,
        municipality: municipality,
        health_facility: facility,
        route_date: Date.current + 1,
        sequence_number: 2
      )
      [ today_route, tomorrow_route ].each do |route|
        VisitRouteProvisioning.create!(
          municipality: municipality,
          health_facility: facility,
          visit_route: route,
          status: "calculated",
          lines_json: [
            {
              "key" => "immunobiological",
              "label" => product.name,
              "quantity_required" => 3,
              "unit" => "dose",
              "immunobiological_product_id" => product.id
            }
          ]
        )
      end
      HomeVisitCampaignProvisioning.create!(
        municipality: municipality,
        health_facility: facility,
        home_visit_campaign: campaign,
        status: "calculated",
        totals_json: []
      )

      result = described_class.call(campaign: campaign, route_date: nil)

      expect(result.blocked).to be(false)
      expect(result.routes_reserved).to eq(2)
      expect(today_route.visit_route_provisioning.reload.status).to eq("reserved")
      expect(tomorrow_route.visit_route_provisioning.reload.status).to eq("reserved")
      expect(lot.reload.quantity_on_hand).to eq(14)
    end
  end
end
