# frozen_string_literal: true

class Appointment < ApplicationRecord
  belongs_to :municipality
  belongs_to :health_facility
  belongs_to :consultation_room
  belongs_to :appointment_service_type
  belongs_to :citizen
  belongs_to :care_team, optional: true
  belongs_to :professional, class_name: "User", optional: true
  has_one :appointment_room_slot, dependent: :destroy
  has_one :encounter, dependent: :nullify

  STATUSES = %w[scheduled confirmed checked_in in_progress completed cancelled no_show].freeze
  CHANNELS = %w[citizen_app web_reception walk_in].freeze

  validates :municipality_id, :health_facility_id, :consultation_room_id, :appointment_service_type_id,
            :citizen_id, :scheduled_at, :status, :kind, :channel, :modality, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :channel, inclusion: { in: CHANNELS }
  validates :duration_minutes, numericality: { greater_than: 0 }

  scope :for_day, ->(day) { where(scheduled_at: day.all_day) }
  scope :active, -> { where.not(status: %w[cancelled no_show completed]) }
end
