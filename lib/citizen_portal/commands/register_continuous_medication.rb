# frozen_string_literal: true

module CitizenPortal
  module Commands
    class RegisterContinuousMedication < ApplicationCommand
      def initialize(medication_name:, dosage: nil, frequency: nil, started_on: nil)
        @medication_name = medication_name
        @dosage = dosage
        @frequency = frequency
        @started_on = started_on
      end

      def call
        tenant = Cidadaobr::TenantContext.current_or_raise!
        citizen = Citizen.find(tenant.citizen_id)

        write_transaction do
          medication = CitizenContinuousMedication.create!(
            municipality_id: citizen.municipality_id,
            citizen_id: citizen.id,
            medication_name: @medication_name,
            dosage: @dosage,
            frequency: @frequency,
            started_on: @started_on || Date.current,
            active: true
          )

          RecordPlatformEvent.call(
            event_type: Cidadaobr::KafkaTopics::CONTINUOUS_MEDICATION_REGISTERED,
            aggregate_type: "CitizenContinuousMedication",
            aggregate_id: medication.id,
            care_team_id: CareTeamRouting.resolve_care_team_id(citizen),
            payload: {
              continuous_medication_id: medication.id,
              citizen_id: medication.citizen_id,
              medication_name: medication.medication_name,
              started_on: medication.started_on&.iso8601
            }
          )

          medication
        end
      end
    end
  end
end
