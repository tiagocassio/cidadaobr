# frozen_string_literal: true

class AppointmentServiceType < ApplicationRecord
  belongs_to :municipality
  has_many :appointments, dependent: :restrict_with_error

  validates :municipality_id, :code, :name, presence: true
  validates :code, uniqueness: { scope: :municipality_id }
  validates :default_duration_minutes, numericality: { greater_than: 0 }
end
