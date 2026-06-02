# frozen_string_literal: true

module Inventory
  class SupplyItemComponentSync
    # Must run inside a database transaction; clears existing components before re-applying.
    def initialize(item:, municipality_id:, components:, exclude_item_id: nil)
      @item = item
      @municipality_id = municipality_id
      @components = Array(components)
      @exclude_item_id = exclude_item_id
    end

    def apply!(municipality:)
      @item.supply_item_components.destroy_all if @item.persisted?

      normalized = normalize
      return false if normalized.nil?

      normalized.each do |attrs|
        component = @item.supply_item_components.build(
          municipality: municipality,
          component_item_id: attrs[:component_item_id],
          quantity_per_unit: attrs[:quantity_per_unit]
        )
        next if component.save

        copy_component_errors(component)
        return false
      end

      true
    end

    private

    def normalize
      rows = @components.map { |row| row.to_h.symbolize_keys }
      submitted = rows.reject { |row| row[:component_item_id].blank? }

      if submitted.empty?
        @item.errors.add(:base, :composite_requires_components)
        return nil
      end

      seen_ids = {}
      submitted.filter_map do |row|
        component_item_id = row[:component_item_id]
        quantity = parse_quantity(row[:quantity_per_unit])
        if quantity == :blank
          @item.errors.add(:base, :component_quantity_required)
          return nil
        end
        if quantity.nil?
          @item.errors.add(:base, :invalid_component_quantity)
          return nil
        end

        component_item = SupplyItem.find_for_municipality(
          municipality_id: @municipality_id,
          supply_item_id: component_item_id
        )
        if component_item.blank?
          @item.errors.add(:base, :invalid_component_item)
          return nil
        end
        unless component_item.simple?
          @item.errors.add(:base, :component_must_be_simple)
          return nil
        end
        if @exclude_item_id.present? && component_item.id == @exclude_item_id
          @item.errors.add(:base, :invalid_component_reference)
          return nil
        end
        if seen_ids.key?(component_item.id)
          @item.errors.add(:base, :duplicate_component_item)
          return nil
        end

        seen_ids[component_item.id] = true
        { component_item_id: component_item.id, quantity_per_unit: quantity }
      end
    end

    def parse_quantity(raw)
      return :blank if raw.blank?

      quantity = BigDecimal(raw.to_s)
      return if quantity <= 0

      quantity
    rescue ArgumentError
      nil
    end

    def copy_component_errors(component)
      component.errors.each do |error|
        @item.errors.import(error, attribute: :base)
      end
    end
  end
end
