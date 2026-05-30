# frozen_string_literal: true

module Scheduling
  class BookWalkInAppointment < ApplicationCommand
    def initialize(
      citizen_id:,
      appointment_service_type_id:,
      consultation_room_id:,
      care_team_id: nil,
      channel: "walk_in",
      kind: "walk_in",
      modality: "in_person"
    )
      @citizen_id = citizen_id
      @appointment_service_type_id = appointment_service_type_id
      @consultation_room_id = consultation_room_id
      @care_team_id = care_team_id
      @channel = channel
      @kind = kind
      @modality = modality
    end

    def call
      tenant = Cidadaobr::TenantContext.current_or_raise!
      scheduled_at = Time.zone.now.change(sec: 0)

      ActiveRecord::Base.transaction do
        citizen = Citizen.find(@citizen_id)
        service_type = AppointmentServiceType.find(@appointment_service_type_id)
        room = ConsultationRoom.find(@consultation_room_id)

        if citizen.municipality_id != tenant.municipality_id ||
           service_type.municipality_id != tenant.municipality_id ||
           room.municipality_id != tenant.municipality_id
          Scheduling::Errors::SlotUnavailableError.raise!(:outside_municipality)
        end

        care_team_id = resolve_care_team_id!(tenant, citizen, room)

        Appointment.create!(
          municipality_id: tenant.municipality_id,
          health_facility_id: room.health_facility_id,
          consultation_room_id: room.id,
          appointment_service_type_id: service_type.id,
          citizen_id: citizen.id,
          care_team_id: care_team_id,
          scheduled_at: scheduled_at,
          duration_minutes: service_type.default_duration_minutes,
          status: "checked_in",
          kind: @kind,
          channel: @channel,
          modality: @modality
        ).tap do |appointment|
          RecordPlatformEvent.call(
            event_type: "appointment.walk_in_booked",
            aggregate_type: "Appointment",
            aggregate_id: appointment.id,
            payload: {
              appointment_id: appointment.id,
              citizen_id: appointment.citizen_id,
              channel: appointment.channel,
              scheduled_at: appointment.scheduled_at.iso8601
            },
            topic: OutboxPublisher::TOPIC_MAPPING.fetch("appointment.booked"),
            care_team_id: appointment.care_team_id
          )
        end
      end
    end

    private

    def resolve_care_team_id!(tenant, citizen, room)
      team_id = @care_team_id.presence || citizen.care_team_id
      return team_id if team_id.blank?

      team = CareTeam.find_by(id: team_id, municipality_id: tenant.municipality_id)
      unless team && team.health_facility_id == room.health_facility_id
        Scheduling::Errors::SlotUnavailableError.raise!(:care_team_facility_mismatch)
      end

      team.id
    end
  end
end
