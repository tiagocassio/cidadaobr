# frozen_string_literal: true

class FacilityMicroAreaCoverage < ApplicationRecord
  belongs_to :health_facility
  belongs_to :micro_area

  validates :micro_area_id, uniqueness: { scope: :health_facility_id }
end
