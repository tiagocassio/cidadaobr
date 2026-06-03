# frozen_string_literal: true

module Inventory
  class PreviewCampaignProvisioning
    Line = Data.define(:key, :label, :quantity_required, :unit, :calculation_source, :supply_item_id, :immunobiological_product_id)
    RollupView = Data.define(:status, :totals_json)

    class << self
      def preview(campaign:)
        stop_count = campaign.campaign_targets.count
        lines = []

        campaign.supply_plans.includes(:supply_item).each do |plan|
          item = plan.supply_item
          next unless item

          lines << Line.new(
            key: item.id,
            label: item.name,
            quantity_required: (plan.quantity_per_visit.to_d * stop_count).ceil,
            unit: item.unit,
            calculation_source: "campaign_plan:#{stop_count}×stops",
            supply_item_id: item.id,
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
            supply_item_id: nil,
            immunobiological_product_id: product_id
          )
        end

        lines
      end

      def rollup_snapshot(campaign:, route_date: nil)
        state = build_rollup_state(campaign: campaign, route_date: route_date)
        RollupView.new(status: state[:status], totals_json: state[:totals_json])
      end

      def refresh_route_provisionings!(campaign:, route_date: nil)
        campaign_routes_scope(campaign: campaign, route_date: route_date).find_each do |route|
          provisioning = route.visit_route_provisioning
          next if provisioning&.status.in?(%w[reserved dispatched])

          persist_route!(route: route)
        end
      end

      def rollup!(campaign:, route_date: nil)
        state = build_rollup_state(campaign: campaign, route_date: route_date)
        record = HomeVisitCampaignProvisioning.find_or_initialize_by(home_visit_campaign: campaign)
        record.assign_attributes(
          municipality: campaign.municipality,
          health_facility: campaign.health_facility,
          totals_json: state[:totals_json],
          status: state[:status]
        )
        record.save!
        record
      end

      def rollup_status!(campaign:, route_date: nil)
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
        status = resolve_provisioning_status(
          campaign: campaign,
          existing_status: record.status,
          blocked: blocked,
          route_date: route_date,
          totals_empty: totals.blank?
        )

        record.update!(totals_json: totals, status: status)
        record
      end

      def apply_campaign_totals_to_routes!(campaign:, totals:, route_date: nil)
        routes = campaign_routes_scope(campaign: campaign, route_date: route_date)
          .includes(:visit_route_provisioning, :visit_route_stops)
          .to_a
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
              "supply_item_id" => line["supply_item_id"],
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
            "supply_item_id" => line.supply_item_id,
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

      def build_rollup_state(campaign:, route_date: nil)
        totals = Hash.new { |hash, key| hash[key] = { "label" => key, "quantity_required" => 0, "unit" => "unit" } }

        provisioning_routes_scope(campaign: campaign, route_date: route_date).find_each do |route|
          next unless route.visit_route_provisioning

          route.visit_route_provisioning.lines_json.each do |line|
            merge_line_into_totals!(totals, line, accumulate: true)
          end
        end

        unless route_date.present?
          preview(campaign: campaign).each do |line|
            merge_line_into_totals!(totals, line, accumulate: false)
          end
        end

        totals_json = totals.values
        blocked = totals_json.any? do |line|
          available = available_for_line(campaign: campaign, line: line)
          line["quantity_available"] = available
          line["deficit"] = [ line["quantity_required"].to_i - available, 0 ].max
          line["deficit"].positive?
        end

        existing_status = campaign.home_visit_campaign_provisioning&.status
        status = resolve_provisioning_status(
          campaign: campaign,
          existing_status: existing_status,
          blocked: blocked,
          route_date: route_date,
          totals_empty: totals_json.blank?
        )

        { totals_json: totals_json, status: status }
      end

      def provisioning_routes_scope(campaign:, route_date: nil)
        campaign_routes_scope(campaign: campaign, route_date: route_date).includes(:visit_route_provisioning)
      end

      def campaign_routes_scope(campaign:, route_date: nil, statuses: nil)
        scope = VisitRoute.where(home_visit_campaign_id: campaign.id)
        scope = scope.where(status: statuses) if statuses.present?
        route_date.present? ? scope.where(route_date: route_date) : scope
      end

      def merge_line_into_totals!(totals, line, accumulate:)
        attrs = line.is_a?(Line) ? line_to_bucket_attrs(line) : line.stringify_keys
        line_key = bucket_key_for(attrs)
        new_bucket = !totals.key?(line_key)
        bucket = totals[line_key]
        bucket["key"] = attrs["key"].presence || line_key if new_bucket
        bucket["label"] = attrs["label"]
        bucket["unit"] = attrs["unit"]
        bucket["supply_item_id"] = attrs["supply_item_id"]
        bucket["immunobiological_product_id"] = attrs["immunobiological_product_id"]
        qty = attrs["quantity_required"].to_i
        bucket["quantity_required"] = if accumulate
          bucket["quantity_required"] + qty
        else
          [ bucket["quantity_required"], qty ].max
        end
      end

      def bucket_key_for(attrs)
        attrs["supply_item_id"].presence || attrs["immunobiological_product_id"].presence || attrs["key"].presence || attrs["label"]
      end

      def line_to_bucket_attrs(line)
        {
          "key" => line.key,
          "label" => line.label,
          "unit" => line.unit,
          "supply_item_id" => line.supply_item_id,
          "immunobiological_product_id" => line.immunobiological_product_id,
          "quantity_required" => line.quantity_required
        }
      end

      def resolve_provisioning_status(campaign:, existing_status:, blocked:, route_date: nil, totals_empty: false)
        if blocked
          "blocked"
        elsif totals_empty
          "draft"
        elsif routes_pending_reserve?(campaign: campaign, route_date: route_date)
          "calculated"
        elsif existing_status.in?(%w[reserved dispatched])
          existing_status
        else
          "calculated"
        end
      end

      def routes_pending_reserve?(campaign:, route_date: nil)
        campaign_routes_scope(campaign: campaign, route_date: route_date, statuses: %w[draft published])
          .left_joins(:visit_route_provisioning)
          .where("visit_route_provisionings.id IS NULL OR visit_route_provisionings.status NOT IN (?)", %w[reserved dispatched])
          .exists?
      end

      def available_for_line(campaign:, line:)
        line = line.stringify_keys
        case line["unit"]
        when "dose"
          return 0 if line["immunobiological_product_id"].blank?

          Inventory::ProvisioningValidator.available_doses_at(
            municipality_id: campaign.municipality_id,
            health_facility_id: campaign.health_facility_id,
            immunobiological_product_id: line["immunobiological_product_id"]
          )
        else
          supply_item_id = line["supply_item_id"]
          return 0 if supply_item_id.blank?

          product_id = campaign.target_audience_definition.to_h["immunobiological_product_id"]

          Inventory::ProvisioningValidator.available_supply_at(
            municipality_id: campaign.municipality_id,
            health_facility_id: campaign.health_facility_id,
            supply_item_id: supply_item_id,
            immunobiological_product_id: product_id
          )
        end
      end
    end
  end
end
