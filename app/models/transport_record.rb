# frozen_string_literal: true

class TransportRecord < ApplicationRecord
  belongs_to :municipality
  belongs_to :health_facility, optional: true
  belongs_to :care_team, optional: true
  belongs_to :ledi_batch, optional: true
  belongs_to :origin_health_facility, class_name: "HealthFacility", optional: true
  has_one :clinical_record, dependent: :restrict_with_error

  STATUSES = %w[draft validated sent accepted rejected].freeze

  validates :municipality_id, :serialized_uuid, :serialized_type, :cnes, :ibge_code, :payload_binary, :ledi_version, :status, presence: true
  validates :serialized_uuid, uniqueness: { scope: :municipality_id }
  validates :status, inclusion: { in: STATUSES }

  def readonly?
    persisted? && %w[sent accepted].include?(status)
  end
end
