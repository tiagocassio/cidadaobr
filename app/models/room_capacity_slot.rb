# frozen_string_literal: true

class RoomCapacitySlot < ApplicationRecord
  belongs_to :municipality
  belongs_to :health_facility
  belongs_to :consultation_room
  has_many :appointment_room_slots, dependent: :destroy

  validates :municipality_id, :health_facility_id, :consultation_room_id, :slot_date, :starts_at, :ends_at, presence: true
  validates :capacity, numericality: { greater_than: 0 }
  validates :booked_count, numericality: { greater_than_or_equal_to: 0 }

  scope :for_date, ->(date) { where(slot_date: date) }
end
