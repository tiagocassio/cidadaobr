# frozen_string_literal: true

module Inventory
  module Commands
    class ReleaseReservedSupplies
      class << self
        def call(provisioning:)
          return if provisioning.blank?
          return unless provisioning.status == "reserved"

          ActiveRecord::Base.transaction do
            StockMovement.where(
              reference_type: provisioning.class.name,
              reference_id: provisioning.id,
              movement_type: "reserve"
            ).find_each do |movement|
              restore_movement!(movement)
            end

            lines = provisioning.lines_json.map do |line|
              line.stringify_keys.except("allocations", "quantity_reserved")
            end
            provisioning.update!(status: "calculated", lines_json: lines)
          end
        end

        def call_for_routes(routes:)
          routes.includes(:visit_route_provisioning).find_each do |route|
            call(provisioning: route.visit_route_provisioning)
          end
        end

        private

        def restore_movement!(movement)
          if movement.immunobiological_lot_id.present?
            lot = movement.immunobiological_lot
            lot.update!(quantity_on_hand: lot.quantity_on_hand + movement.quantity)
          elsif movement.supply_item_id.present?
            balance = StockBalance.find_by(
              municipality_id: movement.municipality_id,
              health_facility_id: movement.health_facility_id,
              supply_item_id: movement.supply_item_id
            )
            balance&.update!(quantity: balance.quantity + movement.quantity)
          end

          movement.destroy!
        end
      end
    end
  end
end
