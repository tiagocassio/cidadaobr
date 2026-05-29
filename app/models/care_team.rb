# frozen_string_literal: true

class CareTeam < ApplicationRecord
  TEAM_KINDS = IndicatorCatalog::TEAM_KINDS.freeze

  belongs_to :municipality
  belongs_to :health_facility
  has_many :user_team_assignments, dependent: :destroy

  validates :name, :ine, :health_facility_id, presence: true
  validates :ine, uniqueness: { scope: :municipality_id }
  validates :team_kind, inclusion: { in: TEAM_KINDS }, allow_nil: true
  validate :health_facility_belongs_to_municipality

  private

  def health_facility_belongs_to_municipality
    return if health_facility_id.blank?

    facility = HealthFacility.find_by(id: health_facility_id)
    return if facility&.municipality_id == municipality_id

    errors.add(:health_facility_id, :invalid)
  end
end
