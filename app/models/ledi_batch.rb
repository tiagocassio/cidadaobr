# frozen_string_literal: true

class LediBatch < ApplicationRecord
  belongs_to :municipality
  belongs_to :health_facility, optional: true
  belongs_to :care_team, optional: true
  has_many :transport_records, dependent: :restrict_with_error

  STATUSES = %w[draft ready submitted accepted rejected].freeze

  validates :municipality_id, :batch_number, :ledi_version, :status, presence: true
  validates :batch_number, uniqueness: { scope: :municipality_id }
  validates :status, inclusion: { in: STATUSES }

  def readonly?
    persisted? && %w[submitted accepted].include?(status)
  end
end
