# frozen_string_literal: true

module Territory
  module Commands
    class UpdateHealthFacility < ApplicationCommand
      Result = Data.define(:success, :health_facility, :invalid_coordinates)

      def initialize(health_facility:, attributes:)
        @health_facility = health_facility
        @raw_attributes = attributes.stringify_keys
      end

      def call
        location = Territory::FacilityLocation.apply!(
          @raw_attributes,
          latitude: @raw_attributes["latitude"],
          longitude: @raw_attributes["longitude"]
        )
        if location.invalid_coordinates
          add_coordinate_errors!
          return Result.new(success: false, health_facility: @health_facility, invalid_coordinates: true)
        end

        @health_facility.assign_attributes(location.attributes)
        success = @health_facility.save
        Result.new(success: success, health_facility: @health_facility, invalid_coordinates: false)
      end

      private

      def add_coordinate_errors!
        @health_facility.errors.add(:latitude, I18n.t("cidadaobr.health_facilities.flash.invalid_coordinates"))
        @health_facility.errors.add(:longitude, I18n.t("cidadaobr.health_facilities.flash.invalid_coordinates"))
      end
    end
  end
end
