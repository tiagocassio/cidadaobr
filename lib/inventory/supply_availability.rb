# frozen_string_literal: true

module Inventory
  class SupplyAvailability
    class << self
      def quantity_on_hand(municipality_id:, health_facility_id:, item:)
        StockBalance
          .where(
            municipality_id: municipality_id,
            health_facility_id: health_facility_id,
            supply_item_id: item.id
          )
          .sum(:quantity)
          .to_i
      end

      def available_at(municipality_id:, health_facility_id:, item:, committed_syringes: 0)
        if item.composite?
          available_composite_at(
            municipality_id: municipality_id,
            health_facility_id: health_facility_id,
            item: item
          )
        elsif item.category == "syringe" && committed_syringes.positive?
          [ quantity_on_hand(municipality_id: municipality_id, health_facility_id: health_facility_id, item: item) - committed_syringes, 0 ].max
        else
          quantity_on_hand(municipality_id: municipality_id, health_facility_id: health_facility_id, item: item)
        end
      end

      def available_composite_at(municipality_id:, health_facility_id:, item:)
        requirements = item.leaf_requirements(1)
        return 0 if requirements.empty?

        requirements.map do |requirement|
          on_hand = quantity_on_hand(
            municipality_id: municipality_id,
            health_facility_id: health_facility_id,
            item: requirement.item
          )
          (on_hand / requirement.quantity).floor
        end.min
      end

      def available_for_item(municipality_id:, health_facility_id:, supply_item_id:, committed_syringes: 0)
        item = SupplyItem.find_for_municipality(municipality_id: municipality_id, supply_item_id: supply_item_id)
        return 0 unless item

        available_at(
          municipality_id: municipality_id,
          health_facility_id: health_facility_id,
          item: item,
          committed_syringes: committed_syringes
        )
      end
    end
  end
end
