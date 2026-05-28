# frozen_string_literal: true

class AppointmentRoomSlot < ApplicationRecord
  belongs_to :municipality
  belongs_to :health_facility
  belongs_to :room_capacity_slot
  belongs_to :appointment, optional: true

  STATUSES = %w[available reserved].freeze

  validates :municipality_id, :health_facility_id, :room_capacity_slot_id, :status, presence: true
  validates :status, inclusion: { in: STATUSES }
end
