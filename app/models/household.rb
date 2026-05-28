# frozen_string_literal: true

class Household < ApplicationRecord
  belongs_to :municipality
  belongs_to :health_facility, optional: true
  belongs_to :care_team, optional: true
  belongs_to :clinical_record, optional: true
  has_many :household_members, dependent: :destroy
  has_many :citizens, through: :household_members
  has_many :household_animals, dependent: :destroy

  validates :municipality_id, :ibge_code, presence: true

  scope :with_location, -> { where.not(location: nil) }
  scope :within_radius, ->(lng, lat, meters) {
    point = Cidadaobr::GeoPoint.build(lng: lng, lat: lat)
    where(arel_table[:location].st_dwithin(point, meters))
  }

  def self.nearest_to(lng, lat, limit: 10)
    point = Cidadaobr::GeoPoint.build(lng: lng, lat: lat)
    with_location
      .order(arel_table[:location].distance_operator(point))
      .limit(limit)
  end

  def self.within_micro_area(micro_area)
    return none if micro_area.coverage.blank?

    where(arel_table[:location].st_within(micro_area.coverage))
  end

  def coordinates
    return nil unless location

    { lat: location.y, lng: location.x }
  end
end
