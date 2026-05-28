# frozen_string_literal: true

class OutboxMessage < ApplicationRecord
  STATUSES = %w[pending published failed].freeze

  validates :domain_event_id, :municipality_id, :topic, :event_type, :status, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :pending, -> { where(status: "pending") }
end
