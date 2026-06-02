# frozen_string_literal: true

require "rails_helper"

RSpec.describe Inventory::Commands::UpdateCampaignProvisioning do
  let(:municipality) { create(:municipality) }
  let(:facility) { create(:health_facility, municipality: municipality) }
  let(:campaign) { create(:home_visit_campaign, municipality: municipality, health_facility: facility) }
  let(:membership) { create(:user_municipality_membership, municipality: municipality, scope: "municipality") }

  it "rejects updates when provisioning is reserved" do
    with_tenant(membership) do
    HomeVisitCampaignProvisioning.create!(
      municipality: municipality,
      health_facility: facility,
      home_visit_campaign: campaign,
      status: "reserved",
      totals_json: [ { "key" => "x", "label" => "X", "quantity_required" => 1, "unit" => "unit" } ]
    )

    expect do
      described_class.call(
        campaign: campaign,
        totals: [ { key: "x", label: "X", quantity_required: 2, unit: "unit" } ]
      )
    end.to raise_error(ArgumentError, /bloqueado/)
    end
  end

  it "propagates campaign totals to editable route provisionings" do
    with_tenant(membership) do
      campaign = create(:home_visit_campaign, municipality: municipality, health_facility: facility)
      route = create(
        :visit_route,
        home_visit_campaign: campaign,
        municipality: municipality,
        health_facility: facility,
        care_team: create(:care_team, municipality: municipality, health_facility: facility)
      )
      create(:visit_route_stop, visit_route: route, municipality: municipality, stop_order: 1)
      VisitRouteProvisioning.create!(
        municipality: municipality,
        health_facility: facility,
        visit_route: route,
        status: "calculated",
        lines_json: [ { "key" => "gloves", "label" => "Luvas", "quantity_required" => 1, "unit" => "unit" } ]
      )
      HomeVisitCampaignProvisioning.create!(
        municipality: municipality,
        health_facility: facility,
        home_visit_campaign: campaign,
        status: "calculated",
        totals_json: [ { "key" => "gloves", "label" => "Luvas", "quantity_required" => 1, "unit" => "unit" } ]
      )

      described_class.call(
        campaign: campaign,
        totals: [ { key: "gloves", label: "Luvas", quantity_required: 10, unit: "unit" } ]
      )

      expect(route.visit_route_provisioning.reload.lines_json.first["quantity_required"]).to eq(10)
    end
  end

  it "keeps route totals aligned with campaign totals across multiple routes" do
    with_tenant(membership) do
      campaign = create(:home_visit_campaign, municipality: municipality, health_facility: facility)
      route_a = create(
        :visit_route,
        home_visit_campaign: campaign,
        municipality: municipality,
        health_facility: facility,
        care_team: create(:care_team, municipality: municipality, health_facility: facility),
        sequence_number: 1
      )
      route_b = create(
        :visit_route,
        home_visit_campaign: campaign,
        municipality: municipality,
        health_facility: facility,
        care_team: create(:care_team, municipality: municipality, health_facility: facility),
        sequence_number: 2
      )
      create(:visit_route_stop, visit_route: route_a, municipality: municipality, stop_order: 1)
      create(:visit_route_stop, visit_route: route_a, municipality: municipality, stop_order: 2)
      create(:visit_route_stop, visit_route: route_b, municipality: municipality, stop_order: 1)
      [ route_a, route_b ].each do |route|
        VisitRouteProvisioning.create!(
          municipality: municipality,
          health_facility: facility,
          visit_route: route,
          status: "calculated",
          lines_json: [ { "key" => "gloves", "label" => "Luvas", "quantity_required" => 1, "unit" => "unit" } ]
        )
      end
      HomeVisitCampaignProvisioning.create!(
        municipality: municipality,
        health_facility: facility,
        home_visit_campaign: campaign,
        status: "calculated",
        totals_json: [ { "key" => "gloves", "label" => "Luvas", "quantity_required" => 1, "unit" => "unit" } ]
      )

      described_class.call(
        campaign: campaign,
        totals: [ { key: "gloves", label: "Luvas", quantity_required: 10, unit: "unit" } ]
      )

      route_totals = [ route_a, route_b ].flat_map do |route|
        route.visit_route_provisioning.reload.lines_json.map { |line| line["quantity_required"].to_i }
      end
      expect(route_totals.sum).to eq(10)
    end
  end

  it "applies totals only to routes on the given route_date" do
    with_tenant(membership) do
      campaign = create(:home_visit_campaign, municipality: municipality, health_facility: facility)
      team = create(:care_team, municipality: municipality, health_facility: facility)
      today = Date.current
      tomorrow = today + 1.day
      route_today = create(
        :visit_route,
        home_visit_campaign: campaign,
        municipality: municipality,
        health_facility: facility,
        care_team: team,
        route_date: today
      )
      route_tomorrow = create(
        :visit_route,
        home_visit_campaign: campaign,
        municipality: municipality,
        health_facility: facility,
        care_team: team,
        route_date: tomorrow,
        sequence_number: 2
      )
      create(:visit_route_stop, visit_route: route_today, municipality: municipality, stop_order: 1)
      create(:visit_route_stop, visit_route: route_tomorrow, municipality: municipality, stop_order: 1)
      [ route_today, route_tomorrow ].each do |route|
        VisitRouteProvisioning.create!(
          municipality: municipality,
          health_facility: facility,
          visit_route: route,
          status: "calculated",
          lines_json: [ { "key" => "gloves", "label" => "Luvas", "quantity_required" => 1, "unit" => "unit" } ]
        )
      end
      HomeVisitCampaignProvisioning.create!(
        municipality: municipality,
        health_facility: facility,
        home_visit_campaign: campaign,
        status: "calculated",
        totals_json: [ { "key" => "gloves", "label" => "Luvas", "quantity_required" => 1, "unit" => "unit" } ]
      )

      described_class.call(
        campaign: campaign,
        totals: [ { key: "gloves", label: "Luvas", quantity_required: 10, unit: "unit" } ],
        route_date: today
      )

      expect(route_today.visit_route_provisioning.reload.lines_json.first["quantity_required"]).to eq(10)
      expect(route_tomorrow.visit_route_provisioning.reload.lines_json.first["quantity_required"]).to eq(1)
    end
  end
end
