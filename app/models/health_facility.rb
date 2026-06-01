# frozen_string_literal: true

class HealthFacility < ApplicationRecord
  SERVICE_KINDS = %w[primary_care zoonoses].freeze

  belongs_to :municipality
  has_many :care_teams, dependent: :destroy
  has_many :user_municipality_memberships, dependent: :nullify

  validates :name, :facility_service_kind, :cnes, presence: true
  validates :cnes, uniqueness: { scope: :municipality_id }

  def coordinates
    return nil unless location

    { lat: location.y, lng: location.x }
  end
end
