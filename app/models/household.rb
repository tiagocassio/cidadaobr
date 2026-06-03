# frozen_string_literal: true

class Household < ApplicationRecord
  include HouseholdFcdPayload

  belongs_to :municipality
  belongs_to :health_facility, optional: true
  belongs_to :care_team, optional: true
  belongs_to :clinical_record, optional: true
  has_many :household_members, dependent: :destroy
  has_many :citizens, through: :household_members
  has_many :household_animals, dependent: :destroy

  validates :municipality_id, :ibge_code, presence: true

  attr_accessor :latitude, :longitude, :include, :family_reference

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

    column = "#{connection.quote_table_name(table_name)}.#{connection.quote_column_name(:location)}"
    sql, bind = Cidadaobr::GeoPoint.within_geography_sql(column: column, region: micro_area.coverage)
    where(sql, bind)
  end

  def coordinates
    return nil unless location

    { lat: location.y, lng: location.x }
  end

  def latitude
    @latitude.presence || coordinates&.dig(:lat)
  end

  def longitude
    @longitude.presence || coordinates&.dig(:lng)
  end

  def housing_conditions
    super.presence || {}
  end
end
