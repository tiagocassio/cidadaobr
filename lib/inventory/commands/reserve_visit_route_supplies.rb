# frozen_string_literal: true

module Inventory
  module Commands
    class ReserveVisitRouteSupplies < ApplicationCommand
      Result = Data.define(:routes_reserved, :blocked, :message, :shortages)

      def initialize(campaign:, route_date: nil)
        @campaign = campaign
        @route_date = route_date
      end

      def call
        shortages = []
        routes_reserved = 0
        blocked = false

        write_transaction do
          Inventory::ProvisioningValidator.lock_stock_for_home_visit!(campaign: @campaign)

          routes = @campaign.visit_routes.includes(:visit_route_provisioning)
          routes = routes.where(route_date: @route_date) if @route_date.present?

          readiness = readiness_error(routes: routes)
          if readiness
            blocked = true
            shortages << readiness
            routes_reserved = 0
            raise ActiveRecord::Rollback
          end

          routes.find_each do |route|
            provisioning = route.visit_route_provisioning
            next if provisioning.status == "reserved"

            outcome = reserve_provisioning!(provisioning: provisioning)
            if outcome[:shortages].any?
              shortages.concat(outcome[:shortages])
              blocked = true
              break
            end

            provisioning.update!(status: "reserved", lines_json: outcome[:lines])
            routes_reserved += 1
          end

          if blocked
            routes_reserved = 0
            raise ActiveRecord::Rollback
          end

          sync_campaign_provisioning!(blocked: false)
        end

        if !blocked && routes_reserved.positive?
          emit_supplies_reserved!(routes_reserved: routes_reserved)
        end

        message = if blocked
          shortages.first || I18n.t("cidadaobr.campaigns.home_visit.flash.reserve_blocked")
        end

        Result.new(
          routes_reserved: routes_reserved,
          blocked: blocked,
          message: message,
          shortages: shortages.uniq
        )
      end

      private

      def reserve_provisioning!(provisioning:)
        lines = provisioning.lines_json.map(&:stringify_keys)
        shortages = []
        updated_lines = lines.map do |line|
          reserve_line(line: line, provisioning: provisioning, shortages: shortages)
        end
        { lines: updated_lines, shortages: shortages }
      end

      def reserve_line(line:, provisioning:, shortages:)
        required = line["quantity_required"].to_i
        return line if required <= 0

        if line["immunobiological_product_id"].present?
          allocations, remaining = allocate_doses_fefo(
            product_id: line["immunobiological_product_id"],
            quantity: required,
            provisioning: provisioning
          )
          line["allocations"] = allocations
          line["quantity_reserved"] = required - remaining
          if remaining.positive?
            shortages << "#{line['label']}: required #{required}, reserved #{required - remaining}"
          end
        else
          item = SupplyLineReference.resolve_item(municipality_id: @campaign.municipality_id, attrs: line)
          if item.blank?
            line["quantity_reserved"] = 0
            shortages << "#{line['label']}: missing supply item code"
          else
            allocations = []
            shortfall = false
            item.leaf_requirements(required).each do |requirement|
              part_allocations, remaining = allocate_supply_item(
                item: requirement.item,
                quantity: requirement.quantity.ceil,
                provisioning: provisioning
              )
              allocations.concat(part_allocations)
              shortfall = true if remaining.positive?
            end
            line["allocations"] = allocations
            line["supply_item_id"] = item.id
            if shortfall
              line["quantity_reserved"] = 0
              shortages << "#{line['label']}: required #{required}, could not reserve all components"
            else
              line["quantity_reserved"] = required
            end
          end
        end

        line
      end

      def allocate_doses_fefo(product_id:, quantity:, provisioning:)
        allocations = []
        remaining = quantity

        ImmunobiologicalLot
          .where(
            municipality_id: @campaign.municipality_id,
            health_facility_id: @campaign.health_facility_id,
            immunobiological_product_id: product_id
          )
          .fefo
          .not_expired
          .lock
          .each do |lot|
            break if remaining <= 0

            take = [ lot.quantity_on_hand.to_i, remaining ].min
            next if take <= 0

            lot.update!(quantity_on_hand: lot.quantity_on_hand - take)
            StockMovement.create!(
              municipality: @campaign.municipality,
              health_facility: @campaign.health_facility,
              immunobiological_lot: lot,
              movement_type: "reserve",
              quantity: take,
              reference_type: provisioning.class.name,
              reference_id: provisioning.id,
              notes: "visit_route_provisioning reserve"
            )
            allocations << { "immunobiological_lot_id" => lot.id, "quantity" => take }
            remaining -= take
          end

        [ allocations, remaining ]
      end

      def allocate_supply_item(item:, quantity:, provisioning:)
        balance = StockBalance.lock.find_by(
          municipality_id: @campaign.municipality_id,
          health_facility_id: @campaign.health_facility_id,
          supply_item_id: item.id
        )
        return [ [], quantity ] unless balance

        take = [ balance.quantity.to_i, quantity ].min
        return [ [], quantity ] if take <= 0

        balance.update!(quantity: balance.quantity - take)
        StockMovement.create!(
          municipality: @campaign.municipality,
          health_facility: @campaign.health_facility,
          supply_item: item,
          movement_type: "reserve",
          quantity: take,
          reference_type: provisioning.class.name,
          reference_id: provisioning.id,
          notes: "visit_route_provisioning reserve"
        )

        [ [ { "supply_item_id" => item.id, "quantity" => take } ], quantity - take ]
      end

      def readiness_error(routes:)
        routes.find_each do |route|
          provisioning = route.visit_route_provisioning
          return I18n.t("cidadaobr.campaigns.home_visit.flash.reserve_missing_provisioning") if provisioning.blank?
          next if provisioning.status == "reserved"

          unless provisioning.status.in?(%w[calculated draft])
            return I18n.t(
              "cidadaobr.campaigns.home_visit.flash.reserve_invalid_provisioning_status",
              status: provisioning.status
            )
          end

          if provisioning.lines_json.blank?
            return I18n.t("cidadaobr.campaigns.home_visit.flash.reserve_empty_kit")
          end
        end

        nil
      end

      def sync_campaign_provisioning!(blocked:)
        record = @campaign.reload.home_visit_campaign_provisioning
        return unless record

        pending = @campaign.visit_routes
          .left_joins(:visit_route_provisioning)
          .where("visit_route_provisioning.id IS NULL OR visit_route_provisioning.status != ?", "reserved")
          .exists?

        record.update!(status: "reserved") unless pending
      end

      def emit_supplies_reserved!(routes_reserved:)
        RecordPlatformEvent.call(
          event_type: Cidadaobr::KafkaTopics::VISIT_ROUTE_SUPPLIES_RESERVED,
          aggregate_type: @campaign.class.name,
          aggregate_id: @campaign.id,
          payload: {
            campaign_id: @campaign.id,
            route_date: @route_date&.iso8601,
            routes_reserved: routes_reserved
          },
)
      end
    end
  end
end
