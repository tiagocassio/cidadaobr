# frozen_string_literal: true

class SupplyProvisioning < ApplicationRecord
  STATUSES = %w[pending approved rejected].freeze

  belongs_to :municipality
  belongs_to :health_facility
  belongs_to :provisionable, polymorphic: true

  validates :status, inclusion: { in: STATUSES }
end
