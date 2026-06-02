# frozen_string_literal: true

module Territory
  class FacilityLocation
    ApplyResult = Data.define(:attributes, :invalid_coordinates)

    class << self
      def apply!(attrs, latitude:, longitude:)
        base = attrs.stringify_keys.except("latitude", "longitude")
        if latitude.blank? && longitude.blank?
          base["location"] = nil
          return ApplyResult.new(attributes: base, invalid_coordinates: false)
        end

        location = Cidadaobr::GeoPoint.from_payload(latitude: latitude, longitude: longitude)
        unless location
          return ApplyResult.new(attributes: base, invalid_coordinates: true)
        end

        base["location"] = location
        ApplyResult.new(attributes: base, invalid_coordinates: false)
      end
    end
  end
end
