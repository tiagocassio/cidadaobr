# frozen_string_literal: true

class TeleconsultationSession < ApplicationRecord
  STATUSES = %w[scheduled active completed cancelled].freeze

  belongs_to :municipality
  belongs_to :citizen
  belongs_to :appointment, optional: true

  validates :status, inclusion: { in: STATUSES }
  validates :scheduled_at, presence: true
end
