# frozen_string_literal: true

class AppointmentWaitlistEntry < ApplicationRecord
  belongs_to :municipality
  belongs_to :health_facility
  belongs_to :appointment_service_type
  belongs_to :citizen

  validates :municipality_id, :health_facility_id, :appointment_service_type_id, :citizen_id, :status, presence: true
end
