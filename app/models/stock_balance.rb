# frozen_string_literal: true

class StockBalance < ApplicationRecord
  belongs_to :municipality
  belongs_to :health_facility
  belongs_to :immunobiological_lot, optional: true
  belongs_to :supply_item, optional: true

  validate :exactly_one_stockable

  validates :quantity, numericality: { greater_than_or_equal_to: 0 }

  private

  def exactly_one_stockable
    present = [ immunobiological_lot_id, supply_item_id ].compact.size
    return if present == 1

    errors.add(:base, :invalid_stockable_reference)
  end
end
