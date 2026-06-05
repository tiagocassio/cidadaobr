# frozen_string_literal: true

module CitizenPortal
  module Commands
    class CreateTeleconsultationSession < ApplicationCommand
      def initialize(scheduled_at:, appointment_id: nil, room_token: nil)
        @scheduled_at = scheduled_at
        @appointment_id = appointment_id
        @room_token = room_token
      end

      def call
        tenant = Cidadaobr::TenantContext.current_or_raise!
        citizen = Citizen.find(tenant.citizen_id)
        appointment_id = validated_appointment_id(citizen)

        write_transaction do
          session = TeleconsultationSession.create!(
            municipality_id: citizen.municipality_id,
            citizen_id: citizen.id,
            appointment_id: appointment_id,
            scheduled_at: @scheduled_at,
            room_token: @room_token || SecureRandom.hex(16),
            status: "scheduled"
          )

          RecordPlatformEvent.call(
            event_type: Cidadaobr::KafkaTopics::TELECONSULTATION_SESSION_CREATED,
            aggregate_type: "TeleconsultationSession",
            aggregate_id: session.id,
            care_team_id: CareTeamRouting.resolve_care_team_id(citizen),
            payload: {
              teleconsultation_session_id: session.id,
              citizen_id: session.citizen_id,
              appointment_id: session.appointment_id,
              scheduled_at: session.scheduled_at.iso8601
            }
          )

          session
        end
      end

      private

      def validated_appointment_id(citizen)
        return nil if @appointment_id.blank?

        appointment = Appointment.find_by(id: @appointment_id, municipality_id: citizen.municipality_id)
        if appointment.nil? || appointment.citizen_id != citizen.id
          raise ArgumentError, "appointment does not belong to citizen"
        end

        appointment.id
      end
    end
  end
end
