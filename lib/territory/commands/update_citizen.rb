# frozen_string_literal: true

module Territory
  module Commands
    class UpdateCitizen < ApplicationCommand
      Result = Data.define(:success, :citizen, :household, :invalid_coordinates)

      def initialize(citizen:, citizen_attributes:, household_attributes: nil, family_reference: false)
        @citizen = citizen
        @citizen_attributes = citizen_attributes.stringify_keys
        @household_attributes = household_attributes&.stringify_keys
        @family_reference = family_reference
      end

      def call
        household = nil
        invalid_coordinates = false

        write_transaction do
          unless @citizen.update(@citizen_attributes)
            raise ActiveRecord::Rollback
          end

          if @household_attributes.present?
            link = LinkCitizenToNewHousehold.call(
              citizen: @citizen,
              household_attributes: @household_attributes,
              family_reference: @family_reference,
              municipality: @citizen.municipality
            )
            unless link.success
              invalid_coordinates = link.invalid_coordinates
              raise ActiveRecord::Rollback
            end

            household = link.household
          end

          emit_updated!(@citizen)
        end

        success = @citizen.errors.none? && !invalid_coordinates
        Result.new(success: success, citizen: @citizen, household: household, invalid_coordinates: invalid_coordinates)
      end

      private

      def emit_updated!(citizen)
        RecordPlatformEvent.call(
          event_type: Cidadaobr::KafkaTopics::CITIZEN_UPDATED,
          aggregate_type: "Citizen",
          aggregate_id: citizen.id,
          payload: {
            citizen_id: citizen.id,
            source: "web_registration"
          },
          care_team_id: citizen.care_team_id
        )
      end
    end
  end
end
