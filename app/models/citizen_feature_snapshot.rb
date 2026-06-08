# frozen_string_literal: true

class CitizenFeatureSnapshot < ApplicationRecord
  FEATURE_SCHEMA_VERSION = "v1"

  belongs_to :municipality
  belongs_to :citizen, optional: true
  belongs_to :clinical_record

  validates :municipality_id, :clinical_record_id, :record_type, :feature_schema_version, :computed_at, presence: true
  validates :features, presence: true
  validates :feature_schema_version, inclusion: { in: [ FEATURE_SCHEMA_VERSION ] }
end
