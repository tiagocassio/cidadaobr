# frozen_string_literal: true

class StockMovement < ApplicationRecord
  MOVEMENT_TYPES = %w[inbound outbound reserve dispatch adjustment].freeze

  belongs_to :municipality
  belongs_to :health_facility
  belongs_to :immunobiologic_lot, optional: true
  belongs_to :supply_item, optional: true

  validates :movement_type, inclusion: { in: MOVEMENT_TYPES }
  validates :quantity, numericality: { greater_than: 0 }
end
