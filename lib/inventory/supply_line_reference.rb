# frozen_string_literal: true

module Inventory
  module SupplyLineReference
    class << self
      def item_id_for(attrs)
        attrs.stringify_keys["supply_item_id"].presence
      end

      def plan_item_id_for(entry)
        entry.stringify_keys["supply_item_id"].presence
      end

      def resolve_item(municipality_id:, attrs:)
        item_id = item_id_for(attrs)
        return if item_id.blank?

        SupplyItem.find_for_municipality(municipality_id: municipality_id, supply_item_id: item_id)
      end

      def resolve_plan_item(municipality_id:, entry:)
        item_id = plan_item_id_for(entry)
        return if item_id.blank?

        SupplyItem.find_for_municipality(municipality_id: municipality_id, supply_item_id: item_id)
      end
    end
  end
end
