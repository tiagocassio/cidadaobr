# frozen_string_literal: true

module Territory
  module Commands
    class LinkCitizenToNewHousehold < ApplicationCommand
      Result = Data.define(:success, :citizen, :household, :invalid_coordinates)

      def initialize(citizen:, household_attributes:, family_reference:, municipality:)
        @citizen = citizen
        @household_attributes = household_attributes
        @family_reference = family_reference
        @municipality = municipality
      end

      def call
        household = Household.new
        Territory::HouseholdPayload.default_from_citizen!(household, @citizen)
        apply = Territory::HouseholdPayload.apply!(
          household: household,
          attributes: @household_attributes,
          municipality: @municipality
        )
        if apply.invalid_coordinates
          @citizen.errors.add(:base, I18n.t("cidadaobr.households.flash.invalid_coordinates"))
          return Result.new(success: false, citizen: @citizen, household: household, invalid_coordinates: true)
        end
        unless apply.valid && household.save
          @citizen.errors.merge!(household.errors)
          return Result.new(success: false, citizen: @citizen, household: household, invalid_coordinates: false)
        end

        LinkCitizenToHousehold.call(
          household: household,
          citizen: @citizen,
          family_reference: @family_reference
        )
        Result.new(success: true, citizen: @citizen, household: household, invalid_coordinates: false)
      end
    end
  end
end
