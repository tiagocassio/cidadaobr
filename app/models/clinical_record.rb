# frozen_string_literal: true

class ClinicalRecord < ApplicationRecord
  RECORD_TYPES = %w[FCI FCD FAI FAO FAC FP FV FVD FAD FAE FCZM FCC MCA].freeze
  VALIDATION_STATUSES = %w[pending valid invalid].freeze

  belongs_to :municipality
  belongs_to :health_facility, optional: true
  belongs_to :care_team, optional: true
  belongs_to :transport_record
  has_many :clinical_record_items, dependent: :destroy
  has_one :citizen, dependent: :nullify
  has_one :household, dependent: :nullify
  has_many :encounters, dependent: :destroy
  # Derived feature rows; cascade delete when the source clinical record is removed.
  has_many :citizen_feature_snapshots, dependent: :destroy

  validates :municipality_id, :transport_record_id, :record_type, :record_uuid, :payload_schema_version, :validation_status, presence: true
  validates :record_uuid, uniqueness: { scope: :municipality_id }
  validates :record_type, inclusion: { in: RECORD_TYPES }
  validates :validation_status, inclusion: { in: VALIDATION_STATUSES }
  validate :validation_errors_must_be_array

  def validation_errors_must_be_array
    return if validation_errors.is_a?(Array)

    errors.add(:validation_errors, :invalid)
  end
end
