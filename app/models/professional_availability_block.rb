# frozen_string_literal: true

class ProfessionalAvailabilityBlock < ApplicationRecord
  belongs_to :municipality
  belongs_to :health_facility
  belongs_to :professional, class_name: "User"

  validates :municipality_id, :health_facility_id, :professional_id, :starts_at, :ends_at, presence: true
end
