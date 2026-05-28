# frozen_string_literal: true

class MicroArea < ApplicationRecord
  belongs_to :municipality
  belongs_to :care_team
  has_many :facility_micro_area_coverages, dependent: :destroy
  has_many :health_facilities, through: :facility_micro_area_coverages

  validates :code, :name, presence: true
  validates :code, uniqueness: { scope: :municipality_id }
  validate :care_team_belongs_to_municipality

  def coverage_bbox
    return nil unless coverage

    points = coverage.exterior_ring.points
    lats = points.map(&:y)
    lngs = points.map(&:x)

    {
      sw_lat: lats.min,
      sw_lng: lngs.min,
      ne_lat: lats.max,
      ne_lng: lngs.max
    }
  end

  def located_households_count
    return 0 if coverage.blank?

    Household.where(municipality_id: municipality_id).within_micro_area(self).count
  end

  def sync_health_facility_coverages!(health_facility_ids)
    valid_ids = HealthFacility.where(municipality_id: municipality_id, id: health_facility_ids).pluck(:id)

    facility_micro_area_coverages.where.not(health_facility_id: valid_ids).destroy_all
    valid_ids.each do |facility_id|
      facility_micro_area_coverages.find_or_create_by!(health_facility_id: facility_id)
    end
  end

  private

  def care_team_belongs_to_municipality
    return if care_team_id.blank?

    team = CareTeam.find_by(id: care_team_id)
    return if team&.municipality_id == municipality_id

    errors.add(:care_team_id, :invalid)
  end
end
