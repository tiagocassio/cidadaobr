# frozen_string_literal: true

class SupplyItem < ApplicationRecord
  belongs_to :municipality
  has_many :stock_balances, dependent: :destroy
  has_many :stock_movements, dependent: :restrict_with_error

  validates :code, :name, :unit, presence: true
  validates :code, uniqueness: { scope: :municipality_id }
end
