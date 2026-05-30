# frozen_string_literal: true

module Inventory
  module Commands
    class ReserveVisitRouteSupplies
      Result = Data.define(:routes_reserved, :blocked, :message, :shortages)

      class << self
        def call(campaign:, route_date: nil)
          shortages = []
          routes_reserved = 0
          blocked = false

          ActiveRecord::Base.transaction do
            Inventory::ProvisioningValidator.lock_stock_for_home_visit!(campaign: campaign)

            routes = campaign.visit_routes.includes(:visit_route_provisioning)
            routes = routes.where(route_date: route_date) if route_date.present?

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

              outcome = reserve_provisioning!(provisioning: provisioning, campaign: campaign)
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

            sync_campaign_provisioning!(campaign: campaign.reload, blocked: false)
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

        def reserve_provisioning!(provisioning:, campaign:)
          lines = provisioning.lines_json.map(&:stringify_keys)
          shortages = []
          updated_lines = lines.map do |line|
            reserve_line(campaign: campaign, line: line, provisioning: provisioning, shortages: shortages)
          end
          { lines: updated_lines, shortages: shortages }
        end

        def reserve_line(campaign:, line:, provisioning:, shortages:)
          required = line["quantity_required"].to_i
          return line if required <= 0

          if line["immunobiological_product_id"].present?
            allocations, remaining = allocate_doses_fefo(
              campaign: campaign,
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
            code = line["supply_item_code"].presence || line["key"]
            if code.blank?
              line["quantity_reserved"] = 0
              shortages << "#{line['label']}: missing supply item code"
            else
              allocations, remaining = allocate_supply_item(
                campaign: campaign,
                code: code,
                quantity: required,
                provisioning: provisioning
              )
              line["allocations"] = allocations
              line["quantity_reserved"] = required - remaining
              if remaining.positive?
                shortages << "#{line['label']}: required #{required}, reserved #{required - remaining}"
              end
            end
          end

          line
        end

        def allocate_doses_fefo(campaign:, product_id:, quantity:, provisioning:)
          allocations = []
          remaining = quantity

          ImmunobiologicalLot
            .where(
              municipality_id: campaign.municipality_id,
              health_facility_id: campaign.health_facility_id,
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
                municipality: campaign.municipality,
                health_facility: campaign.health_facility,
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

        def allocate_supply_item(campaign:, code:, quantity:, provisioning:)
          item = SupplyItem.find_by(municipality_id: campaign.municipality_id, code: code)
          return [ [], quantity ] unless item

          balance = StockBalance.lock.find_by(
            municipality_id: campaign.municipality_id,
            health_facility_id: campaign.health_facility_id,
            supply_item_id: item.id
          )
          return [ [], quantity ] unless balance

          take = [ balance.quantity.to_i, quantity ].min
          return [ [], quantity ] if take <= 0

          balance.update!(quantity: balance.quantity - take)
          StockMovement.create!(
            municipality: campaign.municipality,
            health_facility: campaign.health_facility,
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
          end

          nil
        end

        def sync_campaign_provisioning!(campaign:, blocked:)
          record = campaign.home_visit_campaign_provisioning
          return unless record

          pending = campaign.visit_routes
            .left_joins(:visit_route_provisioning)
            .where("visit_route_provisionings.id IS NULL OR visit_route_provisionings.status != ?", "reserved")
            .exists?

          record.update!(status: "reserved") unless pending
        end
      end
    end
  end
end
