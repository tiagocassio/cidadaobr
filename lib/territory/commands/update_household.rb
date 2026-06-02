# frozen_string_literal: true

module Territory
  module Commands
    class UpdateHousehold < ApplicationCommand
      Result = Data.define(:success, :household, :invalid_coordinates)

      def initialize(household:, household_attributes:, municipality:)
        @household = household
        @household_attributes = household_attributes.stringify_keys
        @municipality = municipality
      end

      def call
        apply = Territory::HouseholdPayload.apply!(
          household: @household,
          attributes: @household_attributes,
          municipality: @municipality
        )
        if apply.invalid_coordinates
          @household.errors.add(:base, I18n.t("cidadaobr.households.flash.invalid_coordinates"))
          return Result.new(success: false, household: @household, invalid_coordinates: true)
        end

        success = apply.valid && @household.save
        Result.new(success: success, household: @household, invalid_coordinates: false)
      end
    end
  end
end
