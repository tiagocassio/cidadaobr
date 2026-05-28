# frozen_string_literal: true

class HouseholdAnimal < ApplicationRecord
  belongs_to :household

  validates :species, :quantity, presence: true
  validates :quantity, numericality: { greater_than: 0, only_integer: true }
end
