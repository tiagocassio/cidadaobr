# frozen_string_literal: true

class ConsultationRoom < ApplicationRecord
  belongs_to :municipality
  belongs_to :health_facility
  has_many :room_capacity_slots, dependent: :destroy
  has_many :appointments, dependent: :restrict_with_error

  validates :municipality_id, :health_facility_id, :name, :room_kind, presence: true
end
