# frozen_string_literal: true

class ImmunobiologicalProduct < ApplicationRecord
  TARGET_SPECIES = %w[human animal].freeze

  belongs_to :municipality
  has_many :immunobiological_lots, dependent: :restrict_with_error
  has_many :vaccination_campaigns, dependent: :restrict_with_error

  validates :code, :name, presence: true
  validates :code, uniqueness: { scope: :municipality_id }
  validates :target_species, inclusion: { in: TARGET_SPECIES }
end
