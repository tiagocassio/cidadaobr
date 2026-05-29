# frozen_string_literal: true

class ImmunobiologicalLot < ApplicationRecord
  belongs_to :municipality
  belongs_to :health_facility
  belongs_to :immunobiological_product
  has_many :stock_balances, dependent: :destroy
  has_many :stock_movements, dependent: :restrict_with_error

  validates :lot_number, :expires_on, presence: true
  validates :lot_number, uniqueness: { scope: %i[health_facility_id immunobiological_product_id] }
  validates :quantity_on_hand, numericality: { greater_than_or_equal_to: 0 }

  after_save :sync_stock_balance_quantity

  scope :not_expired, -> { where("expires_on >= ?", Date.current) }
  scope :fefo, -> { order(:expires_on, :created_at) }

  private

  def sync_stock_balance_quantity
    balance = stock_balances.find_or_initialize_by(
      municipality_id: municipality_id,
      health_facility_id: health_facility_id,
      immunobiological_lot_id: id
    )
    balance.update!(quantity: quantity_on_hand)
  end
end
