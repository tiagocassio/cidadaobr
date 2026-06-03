# frozen_string_literal: true

class MicroArea < ApplicationRecord
  attr_accessor :remove_coverage, :coverage_sw_lat, :coverage_sw_lng, :coverage_ne_lat, :coverage_ne_lng
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
    self.class.located_household_counts_for([ id ]).fetch(id, 0)
  end

  def self.located_household_counts_for(area_ids)
    ids = Array(area_ids).compact_blank
    counts = ids.index_with { 0 }
    return counts if ids.empty?

    covers = Cidadaobr::GeoPoint.geography_covers_sql(
      covering: "micro_areas.coverage",
      covered: "households.location"
    )
    sql = sanitize_sql_array(
      [
        <<~SQL.squish,
          SELECT micro_areas.id AS micro_area_id, COUNT(households.id)::int AS cnt
          FROM micro_areas
          INNER JOIN households
            ON households.municipality_id = micro_areas.municipality_id
            AND households.location IS NOT NULL
            AND #{covers}
          WHERE micro_areas.id IN (?)
            AND micro_areas.coverage IS NOT NULL
          GROUP BY micro_areas.id
        SQL
        ids
      ]
    )
    connection.select_all(sql).each do |row|
      counts[row["micro_area_id"]] = row["cnt"].to_i
    end
    counts
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
