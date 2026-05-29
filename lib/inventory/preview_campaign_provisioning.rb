# frozen_string_literal: true

module Inventory
  class PreviewCampaignProvisioning
    Line = Data.define(:key, :label, :quantity_required, :unit, :calculation_source)

    class << self
      def preview(campaign:)
        stop_count = campaign.campaign_targets.count
        lines = []

        campaign.supply_plan.each do |entry|
          entry = entry.stringify_keys
          qty = (entry["quantity_per_visit"].to_d * stop_count).ceil
          lines << Line.new(
            key: entry["supply_item_code"] || entry["code"],
            label: entry["name"] || entry["supply_item_code"],
            quantity_required: qty,
            unit: entry["unit"] || "unit",
            calculation_source: "campaign_plan:#{stop_count}×stops"
          )
        end

        immunologic_count = campaign.campaign_targets.count
        if immunologic_count.positive? && campaign.target_audience_definition.to_h["immunologic_product_id"].present?
          product = ImmunobiologicProduct.find_by(id: campaign.target_audience_definition["immunologic_product_id"])
          waste = 1 + campaign.waste_factor.to_f
          qty = (immunologic_count * waste).ceil
          lines << Line.new(
            key: "immunologic",
            label: product&.name || "Imunobiológico",
            quantity_required: qty,
            unit: "dose",
            calculation_source: "immunologic:#{immunologic_count}×dose"
          )
        end

        lines
      end

      def rollup!(campaign:)
        totals = Hash.new { |hash, key| hash[key] = { "label" => key, "quantity_required" => 0, "unit" => "unit" } }

        campaign.visit_routes.includes(:visit_route_provisioning).find_each do |route|
          next unless route.visit_route_provisioning

          route.visit_route_provisioning.lines_json.each do |line|
            line = line.stringify_keys
            bucket = totals[line["key"]]
            bucket["label"] = line["label"]
            bucket["unit"] = line["unit"]
            bucket["quantity_required"] += line["quantity_required"].to_i
          end
        end

        preview_lines = preview(campaign: campaign)
        preview_lines.each do |line|
          bucket = totals[line.key]
          bucket["label"] = line.label
          bucket["unit"] = line.unit
          bucket["quantity_required"] = [ bucket["quantity_required"], line.quantity_required ].max
        end

        blocked = totals.values.any? do |line|
          available = available_for_line(campaign: campaign, line: line)
          line["quantity_required"] > available
        end

        record = HomeVisitCampaignProvisioning.find_or_initialize_by(home_visit_campaign: campaign)
        record.assign_attributes(
          municipality: campaign.municipality,
          health_facility: campaign.health_facility,
          totals_json: totals.values,
          status: blocked ? "blocked" : "calculated"
        )
        record.save!
        record
      end

      def persist_route!(route:)
        campaign = route.home_visit_campaign
        stop_count = route.visit_route_stops.count
        lines = preview(campaign: campaign).map do |line|
          scaled = (line.quantity_required.to_d * stop_count / [ campaign.campaign_targets.count, 1 ].max).ceil
          {
            "key" => line.key,
            "label" => line.label,
            "quantity_required" => scaled,
            "unit" => line.unit,
            "calculation_source" => line.calculation_source
          }
        end

        VisitRouteProvisioning.find_or_initialize_by(visit_route: route).tap do |record|
          record.assign_attributes(
            municipality: route.municipality,
            health_facility: route.health_facility,
            lines_json: lines,
            status: "calculated"
          )
          record.save!
        end
      end

      private

      def available_for_line(campaign:, line:)
        case line["unit"]
        when "dose"
          ImmunobiologicLot
            .where(municipality_id: campaign.municipality_id, health_facility_id: campaign.health_facility_id)
            .not_expired
            .sum(:quantity_on_hand)
            .to_i
        else
          StockBalance
            .where(municipality_id: campaign.municipality_id, health_facility_id: campaign.health_facility_id)
            .where.not(supply_item_id: nil)
            .sum(:quantity)
            .to_i
        end
      end
    end
  end
end
