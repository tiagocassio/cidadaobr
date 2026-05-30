# frozen_string_literal: true

module Inventory
  class PreviewCampaignProvisioning
    Line = Data.define(:key, :label, :quantity_required, :unit, :calculation_source, :supply_item_code, :immunobiological_product_id)

    class << self
      def preview(campaign:)
        stop_count = campaign.campaign_targets.count
        lines = []

        campaign.supply_plan.each do |entry|
          entry = entry.stringify_keys
          lines << Line.new(
            key: entry["supply_item_code"] || entry["code"],
            label: entry["name"] || entry["supply_item_code"],
            quantity_required: (entry["quantity_per_visit"].to_d * stop_count).ceil,
            unit: entry["unit"] || "unit",
            calculation_source: "campaign_plan:#{stop_count}×stops",
            supply_item_code: entry["supply_item_code"],
            immunobiological_product_id: nil
          )
        end

        immunobiological_count = campaign.campaign_targets.count
        product_id = campaign.target_audience_definition.to_h["immunobiological_product_id"]
        if immunobiological_count.positive? && product_id.present?
          product = ImmunobiologicalProduct.find_by(id: product_id)
          waste = 1 + campaign.waste_factor.to_f
          qty = (immunobiological_count * waste).ceil
          lines << Line.new(
            key: "immunobiological",
            label: product&.name || "Imunobiológico",
            quantity_required: qty,
            unit: "dose",
            calculation_source: "immunobiological:#{immunobiological_count}×dose",
            supply_item_code: nil,
            immunobiological_product_id: product_id
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
            bucket["supply_item_code"] = line["supply_item_code"]
            bucket["immunobiological_product_id"] = line["immunobiological_product_id"]
            bucket["quantity_required"] += line["quantity_required"].to_i
          end
        end

        preview_lines = preview(campaign: campaign)
        preview_lines.each do |line|
          bucket = totals[line.key]
          bucket["label"] = line.label
          bucket["unit"] = line.unit
          bucket["supply_item_code"] = line.supply_item_code
          bucket["immunobiological_product_id"] = line.immunobiological_product_id
          bucket["quantity_required"] = [ bucket["quantity_required"], line.quantity_required ].max
        end

        blocked = totals.values.any? do |line|
          available = available_for_line(campaign: campaign, line: line)
          line["quantity_available"] = available
          line["deficit"] = [ line["quantity_required"].to_i - available, 0 ].max
          line["deficit"].positive?
        end

        record = HomeVisitCampaignProvisioning.find_or_initialize_by(home_visit_campaign: campaign)
        existing_status = record.status
        status = if blocked
          "blocked"
        elsif existing_status.in?(%w[reserved dispatched])
          existing_status
        else
          "calculated"
        end
        record.assign_attributes(
          municipality: campaign.municipality,
          health_facility: campaign.health_facility,
          totals_json: totals.values,
          status: status
        )
        record.save!
        record
      end

      def rollup_status!(campaign:)
        record = campaign.home_visit_campaign_provisioning
        return unless record

        totals = record.totals_json.map do |line|
          line = line.stringify_keys
          available = available_for_line(campaign: campaign, line: line)
          line.merge(
            "quantity_available" => available,
            "deficit" => [ line["quantity_required"].to_i - available, 0 ].max
          )
        end

        blocked = totals.any? { |line| line["deficit"].to_i.positive? }
        status = if blocked
          "blocked"
        elsif record.status.in?(%w[reserved dispatched])
          record.status
        else
          "calculated"
        end

        record.update!(totals_json: totals, status: status)
        record
      end

      def apply_campaign_totals_to_routes!(campaign:, totals:)
        routes = campaign.visit_routes.includes(:visit_route_provisioning, :visit_route_stops).to_a
        total_stops = routes.sum { |route| route.visit_route_stops.size }
        return if total_stops.zero?

        totals = totals.map(&:stringify_keys)
        lines_by_route = routes.index_with { [] }

        totals.each do |line|
          total_qty = line["quantity_required"].to_i
          remaining = total_qty

          routes.each_with_index do |route, index|
            stop_count = route.visit_route_stops.size
            scaled = if index == routes.size - 1
              remaining
            else
              share = (total_qty * stop_count / total_stops).floor
              remaining -= share
              share
            end

            lines_by_route[route] << {
              "key" => line["key"],
              "label" => line["label"],
              "quantity_required" => scaled,
              "unit" => line["unit"],
              "supply_item_code" => line["supply_item_code"],
              "immunobiological_product_id" => line["immunobiological_product_id"]
            }
          end
        end

        routes.each do |route|
          provisioning = route.visit_route_provisioning
          next if provisioning.blank?
          next if provisioning.status.in?(%w[reserved dispatched])

          provisioning.update!(lines_json: lines_by_route[route], status: "calculated")
        end
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
            "calculation_source" => line.calculation_source,
            "supply_item_code" => line.supply_item_code,
            "immunobiological_product_id" => line.immunobiological_product_id
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
          return 0 if line["immunobiological_product_id"].blank?

          Inventory::ProvisioningValidator.available_doses_at(
            municipality_id: campaign.municipality_id,
            health_facility_id: campaign.health_facility_id,
            immunobiological_product_id: line["immunobiological_product_id"]
          )
        else
          code = line["supply_item_code"].presence || line["key"]
          return 0 if code.blank?

          code_prefix = code.start_with?("SYRINGE") ? "SYRINGE" : code
          product_id = campaign.target_audience_definition.to_h["immunobiological_product_id"]

          Inventory::ProvisioningValidator.available_supply_at(
            municipality_id: campaign.municipality_id,
            health_facility_id: campaign.health_facility_id,
            code_prefix: code_prefix,
            immunobiological_product_id: product_id
          )
        end
      end
    end
  end
end
