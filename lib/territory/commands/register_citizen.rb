# frozen_string_literal: true

module Territory
  module Commands
    class RegisterCitizen < ApplicationCommand
      Result = Data.define(:success, :citizen, :household, :invalid_coordinates)

      def initialize(citizen_attributes:, household_attributes: nil, family_reference: false)
        @citizen_attributes = citizen_attributes.stringify_keys
        @household_attributes = household_attributes&.stringify_keys
        @family_reference = family_reference
      end

      def call
        tenant = Cidadaobr::TenantContext.current_or_raise!
        citizen = Citizen.new(@citizen_attributes.merge("municipality_id" => tenant.municipality_id))
        household = nil
        invalid_coordinates = false

        write_transaction do
          unless citizen.save
            raise ActiveRecord::Rollback
          end

          if @household_attributes.present?
            link = LinkCitizenToNewHousehold.call(
              citizen: citizen,
              household_attributes: @household_attributes,
              family_reference: @family_reference,
              municipality: citizen.municipality
            )
            unless link.success
              citizen.errors.merge!(link.citizen.errors) if link.citizen.errors.any?
              invalid_coordinates = link.invalid_coordinates
              raise ActiveRecord::Rollback
            end

            household = link.household
          end

          emit_registered!(citizen)
        end

        success = citizen.persisted? && citizen.errors.none? && !invalid_coordinates
        Result.new(success: success, citizen: citizen, household: household, invalid_coordinates: invalid_coordinates)
      end

      private

      def emit_registered!(citizen)
        RecordPlatformEvent.call(
          event_type: Cidadaobr::KafkaTopics::CITIZEN_REGISTERED,
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
