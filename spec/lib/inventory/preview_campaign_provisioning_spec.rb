# frozen_string_literal: true

require "rails_helper"

RSpec.describe Inventory::PreviewCampaignProvisioning do
  let(:municipality) { create(:municipality) }
  let(:facility) { create(:health_facility, municipality: municipality) }
  let(:product) { create(:immunobiological_product, municipality: municipality) }
  let(:other_product) { create(:immunobiological_product, municipality: municipality, code: "OTHER") }
  let(:membership) { create(:user_municipality_membership, municipality: municipality, scope: "municipality") }

  it "returns zero available doses when product id is missing" do
    with_tenant(membership) do
      create(
        :immunobiological_lot,
        municipality: municipality,
        health_facility: facility,
        immunobiological_product: product,
        quantity_on_hand: 100
      )
      campaign = create(:home_visit_campaign, municipality: municipality, health_facility: facility)

      available = described_class.send(
        :available_for_line,
        campaign: campaign,
        line: { "unit" => "dose" }
      )

      expect(available).to eq(0)
    end
  end

  it "scopes dose availability to the requested product" do
    with_tenant(membership) do
      create(
        :immunobiological_lot,
        municipality: municipality,
        health_facility: facility,
        immunobiological_product: product,
        quantity_on_hand: 100
      )
      create(
        :immunobiological_lot,
        municipality: municipality,
        health_facility: facility,
        immunobiological_product: other_product,
        quantity_on_hand: 50
      )
      campaign = create(:home_visit_campaign, municipality: municipality, health_facility: facility)

      available = described_class.send(
        :available_for_line,
        campaign: campaign,
        line: { "unit" => "dose", "immunobiological_product_id" => product.id }
      )

      expect(available).to eq(100)
    end
  end

  it "subtracts committed syringes for syringe supply lines" do
    with_tenant(membership) do
      syringe = SupplyItem.create!(
        municipality: municipality,
        name: "Seringa",
        category: "syringe",
        kind: "simple",
        description: "Seringa 1 ml",
        unit: "unit"
      )
      StockBalance.create!(
        municipality: municipality,
        health_facility: facility,
        supply_item: syringe,
        quantity: 500
      )
      VaccinationCampaign.create!(
        municipality: municipality,
        health_facility: facility,
        immunobiological_product: product,
        name: "Campanha vacina",
        campaign_kind: "human_immunization",
        starts_on: Date.current,
        ends_on: Date.current + 6.days,
        target_doses: 400,
        room_capacity_per_day: 50,
        status: "provisioning_approved"
      )
      campaign = create(
        :home_visit_campaign,
        municipality: municipality,
        health_facility: facility,
        target_audience_definition: { "immunobiological_product_id" => product.id }
      )

      available = described_class.send(
        :available_for_line,
        campaign: campaign,
        line: { "unit" => "unit", "supply_item_id" => syringe.id, "key" => syringe.id }
      )

      expect(available).to eq(100)
    end
  end

  it "keeps campaign reserved on rollup scoped to a date with no pending routes" do
    with_tenant(membership) do
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
        target_audience_definition: { "immunobiological_product_id" => product.id }
      )
      team = create(:care_team, municipality: municipality, health_facility: facility)
      today = Date.current
      tomorrow = today + 1.day
      line = {
        "key" => "immunobiological",
        "label" => product.name,
        "quantity_required" => 1,
        "unit" => "dose",
        "immunobiological_product_id" => product.id
      }
      route_today = create(
        :visit_route,
        municipality: municipality,
        health_facility: facility,
        home_visit_campaign: campaign,
        care_team: team,
        route_date: today,
        status: "draft"
      )
      route_tomorrow = create(
        :visit_route,
        municipality: municipality,
        health_facility: facility,
        home_visit_campaign: campaign,
        care_team: team,
        route_date: tomorrow,
        status: "draft"
      )
      VisitRouteProvisioning.create!(
        municipality: municipality,
        health_facility: facility,
        visit_route: route_today,
        status: "reserved",
        lines_json: [ line ]
      )
      VisitRouteProvisioning.create!(
        municipality: municipality,
        health_facility: facility,
        visit_route: route_tomorrow,
        status: "calculated",
        lines_json: [ line ]
      )
      HomeVisitCampaignProvisioning.create!(
        municipality: municipality,
        health_facility: facility,
        home_visit_campaign: campaign,
        status: "reserved",
        totals_json: []
      )

      record = described_class.rollup!(campaign: campaign, route_date: today)

      expect(record.status).to eq("reserved")
    end
  end

  it "scopes rollup totals to route_date when provided" do
    with_tenant(membership) do
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
        target_audience_definition: { "immunobiological_product_id" => product.id }
      )
      team = create(:care_team, municipality: municipality, health_facility: facility)
      today = Date.current
      tomorrow = today + 1.day
      line = {
        "key" => "immunobiological",
        "label" => product.name,
        "quantity_required" => 1,
        "unit" => "dose",
        "immunobiological_product_id" => product.id
      }
      route_today = create(
        :visit_route,
        municipality: municipality,
        health_facility: facility,
        home_visit_campaign: campaign,
        care_team: team,
        route_date: today,
        status: "draft"
      )
      route_tomorrow = create(
        :visit_route,
        municipality: municipality,
        health_facility: facility,
        home_visit_campaign: campaign,
        care_team: team,
        route_date: tomorrow,
        status: "draft"
      )
      VisitRouteProvisioning.create!(
        municipality: municipality,
        health_facility: facility,
        visit_route: route_today,
        status: "calculated",
        lines_json: [ line.merge("quantity_required" => 2) ]
      )
      VisitRouteProvisioning.create!(
        municipality: municipality,
        health_facility: facility,
        visit_route: route_tomorrow,
        status: "calculated",
        lines_json: [ line.merge("quantity_required" => 9) ]
      )

      record = described_class.rollup!(campaign: campaign, route_date: today)

      expect(record.totals_json.sum { |entry| entry["quantity_required"] }).to eq(2)
      expect(record.totals_json.first["key"]).to eq("immunobiological")
    end
  end

  it "returns day-scoped totals in rollup_snapshot without persisting" do
    with_tenant(membership) do
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
        target_audience_definition: { "immunobiological_product_id" => product.id }
      )
      team = create(:care_team, municipality: municipality, health_facility: facility)
      today = Date.current
      tomorrow = today + 1.day
      line = {
        "key" => "immunobiological",
        "label" => product.name,
        "quantity_required" => 1,
        "unit" => "dose",
        "immunobiological_product_id" => product.id
      }
      [ today, tomorrow ].each_with_index do |date, index|
        route = create(
          :visit_route,
          municipality: municipality,
          health_facility: facility,
          home_visit_campaign: campaign,
          care_team: team,
          route_date: date,
          sequence_number: index + 1
        )
        VisitRouteProvisioning.create!(
          municipality: municipality,
          health_facility: facility,
          visit_route: route,
          status: "calculated",
          lines_json: [ line.merge("quantity_required" => index + 2) ]
        )
      end
      HomeVisitCampaignProvisioning.create!(
        municipality: municipality,
        health_facility: facility,
        home_visit_campaign: campaign,
        status: "calculated",
        totals_json: [ line.merge("quantity_required" => 99) ]
      )

      snapshot = described_class.rollup_snapshot(campaign: campaign, route_date: today)

      expect(snapshot.totals_json.sum { |entry| entry["quantity_required"] }).to eq(2)
      expect(campaign.home_visit_campaign_provisioning.reload.totals_json.first["quantity_required"]).to eq(99)
    end
  end

  it "downgrades status on rollup_status when routes still need reserve" do
    with_tenant(membership) do
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
        target_audience_definition: { "immunobiological_product_id" => product.id }
      )
      team = create(:care_team, municipality: municipality, health_facility: facility)
      tomorrow = Date.current + 1.day
      route = create(
        :visit_route,
        municipality: municipality,
        health_facility: facility,
        home_visit_campaign: campaign,
        care_team: team,
        route_date: tomorrow,
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
        status: "reserved",
        totals_json: [
          {
            "key" => "immunobiological",
            "label" => product.name,
            "quantity_required" => 1,
            "unit" => "dose",
            "immunobiological_product_id" => product.id,
            "quantity_available" => 100,
            "deficit" => 0
          }
        ]
      )

      record = described_class.rollup_status!(campaign: campaign)

      expect(record.status).to eq("calculated")
    end
  end
end
