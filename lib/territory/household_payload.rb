# frozen_string_literal: true

module Territory
  # Applies FCD web household attributes from a normalized hash (controllers build the hash).
  class HouseholdPayload
    ApplyResult = Data.define(:valid, :invalid_coordinates)

    class << self
      def apply!(household:, attributes:, municipality:)
        raw = attributes.stringify_keys
        location, invalid_coordinates = location_from_raw(raw)
        return ApplyResult.new(valid: false, invalid_coordinates: true) if invalid_coordinates

        attrs = raw.except("latitude", "longitude", "family_reference", "housing_conditions")
        attrs["location"] = location if location
        attrs["no_street_number"] = boolean(attrs["no_street_number"])
        attrs["outside_micro_area"] = boolean(attrs["outside_micro_area"])
        attrs["animals_on_premises"] = boolean(attrs["animals_on_premises"])
        household.assign_attributes(attrs)
        household.housing_conditions = raw["housing_conditions"].to_h.compact_blank if raw["housing_conditions"].present?
        household.web_fcd_registration = true
        household.municipality = municipality
        household.ibge_code = municipality.ibge_code

        ApplyResult.new(valid: household.valid?, invalid_coordinates: false)
      end

      def default_from_citizen!(household, citizen)
        household.health_facility_id ||= citizen.health_facility_id
        household.care_team_id ||= citizen.care_team_id
      end

      private

      def location_from_raw(raw)
        latitude = raw["latitude"]
        longitude = raw["longitude"]
        return [ nil, false ] if latitude.blank? || longitude.blank?

        location = Cidadaobr::GeoPoint.from_payload(latitude: latitude, longitude: longitude)
        return [ nil, true ] unless location

        [ location, false ]
      end

      def boolean(value)
        ActiveModel::Type::Boolean.new.cast(value) || false
      end
    end
  end
end
