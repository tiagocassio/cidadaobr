# frozen_string_literal: true

module Cidadaobr
  module GeoPoint
    BRAZIL_LAT_RANGE = (-34.0..5.5).freeze
    BRAZIL_LNG_RANGE = (-74.0..-28.0).freeze

    module_function

    def factory
      @factory ||= RGeo::Geographic.spherical_factory(srid: 4326)
    end

    def build(lng:, lat:)
      factory.point(lng.to_f, lat.to_f)
    end

    def valid_brazil_coordinates?(lng:, lat:)
      BRAZIL_LNG_RANGE.cover?(lng.to_f) && BRAZIL_LAT_RANGE.cover?(lat.to_f)
    end

    def from_payload(latitude:, longitude:)
      return nil if latitude.blank? || longitude.blank?

      lng = longitude.to_f
      lat = latitude.to_f
      return nil unless valid_brazil_coordinates?(lng: lng, lat: lat)

      build(lng: lng, lat: lat)
    end

    def from_clinical_record_payload(payload)
      from_payload(
        latitude: payload["latitude"],
        longitude: payload["longitude"]
      )
    end

    def valid_bbox?(sw_lat:, sw_lng:, ne_lat:, ne_lng:)
      sw_lat = sw_lat.to_f
      sw_lng = sw_lng.to_f
      ne_lat = ne_lat.to_f
      ne_lng = ne_lng.to_f
      return false unless sw_lat <= ne_lat && sw_lng <= ne_lng

      [
        [ sw_lng, sw_lat ],
        [ ne_lng, sw_lat ],
        [ ne_lng, ne_lat ],
        [ sw_lng, ne_lat ]
      ].all? { |lng, lat| valid_brazil_coordinates?(lng: lng, lat: lat) }
    end

    def bbox_polygon(sw_lat:, sw_lng:, ne_lat:, ne_lng:)
      return nil unless valid_bbox?(sw_lat: sw_lat, sw_lng: sw_lng, ne_lat: ne_lat, ne_lng: ne_lng)

      factory = self.factory
      ring = factory.linear_ring([
        factory.point(sw_lng, sw_lat),
        factory.point(ne_lng, sw_lat),
        factory.point(ne_lng, ne_lat),
        factory.point(sw_lng, ne_lat),
        factory.point(sw_lng, sw_lat)
      ])
      factory.polygon(ring)
    end
  end
end
