# frozen_string_literal: true

class Encounter < ApplicationRecord
  belongs_to :municipality
  belongs_to :health_facility, optional: true
  belongs_to :care_team, optional: true
  belongs_to :citizen, optional: true
  belongs_to :clinical_record, optional: true
  belongs_to :clinical_record_item, optional: true
  belongs_to :appointment, optional: true

  validates :municipality_id, :record_type, :encounter_at, presence: true
  validates :record_type, inclusion: { in: ClinicalRecord::RECORD_TYPES }
end
