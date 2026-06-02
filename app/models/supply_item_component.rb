# frozen_string_literal: true

class SupplyItemComponent < ApplicationRecord
  belongs_to :municipality
  belongs_to :composite_item, class_name: "SupplyItem", inverse_of: :supply_item_components
  belongs_to :component_item, class_name: "SupplyItem"

  validates :quantity_per_unit, numericality: { greater_than: 0 }
  validates :component_item_id, uniqueness: { scope: :composite_item_id }
  validate :composite_is_composite_kind
  validate :component_is_simple_kind
  validate :component_is_not_parent

  before_validation :sync_municipality_from_composite_item

  private

  def sync_municipality_from_composite_item
    self.municipality_id = composite_item.municipality_id if composite_item.present?
  end

  def composite_is_composite_kind
    return if composite_item.blank?
    return if composite_item.composite?

    errors.add(:composite_item_id, :must_be_composite)
  end

  def component_is_simple_kind
    return if component_item.blank?
    return if component_item.simple?

    errors.add(:component_item_id, :must_be_simple)
  end

  def component_is_not_parent
    return if composite_item_id.blank? || component_item_id.blank?
    return if composite_item_id != component_item_id

    errors.add(:component_item_id, :invalid_component_reference)
  end
end
