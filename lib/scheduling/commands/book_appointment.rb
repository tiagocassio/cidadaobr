# frozen_string_literal: true

module Scheduling
  class BookAppointment < ApplicationCommand
    def initialize(
      citizen_id:,
      appointment_service_type_id:,
      consultation_room_id:,
      scheduled_at:,
      room_capacity_slot_id: nil,
      care_team_id: nil,
      channel: "web_reception",
      kind: "scheduled",
      modality: "in_person"
    )
      @citizen_id = citizen_id
      @appointment_service_type_id = appointment_service_type_id
      @consultation_room_id = consultation_room_id
      @scheduled_at = scheduled_at
      @room_capacity_slot_id = room_capacity_slot_id
      @care_team_id = care_team_id
      @channel = channel
      @kind = kind
      @modality = modality
    end

    def call
      tenant = Cidadaobr::TenantContext.current_or_raise!

      ActiveRecord::Base.transaction do
        citizen = Citizen.find(@citizen_id)
        service_type = AppointmentServiceType.find(@appointment_service_type_id)
        room = ConsultationRoom.find(@consultation_room_id)
        capacity_slot = find_capacity_slot!(room)
        validate_booking_inputs!(tenant, citizen, service_type, room, capacity_slot)
        validate_citizen_app_facility!(citizen, room)
        care_team_id = resolve_care_team_id!(tenant, citizen, room)
        @scheduled_at = BookingGuards.coerce_scheduled_at_for_slot!(@scheduled_at, capacity_slot)

        appointment = Appointment.create!(
          municipality_id: tenant.municipality_id,
          health_facility_id: room.health_facility_id,
          consultation_room_id: room.id,
          appointment_service_type_id: service_type.id,
          citizen_id: citizen.id,
          care_team_id: care_team_id,
          scheduled_at: @scheduled_at,
          duration_minutes: service_type.default_duration_minutes,
          status: "scheduled",
          kind: @kind,
          channel: @channel,
          modality: @modality
        )

        AppointmentRoomSlot.create!(
          municipality_id: tenant.municipality_id,
          health_facility_id: room.health_facility_id,
          room_capacity_slot: capacity_slot,
          appointment: appointment,
          status: "reserved"
        )

        # Citizen slot UPDATE policy requires a reserved appointment_room_slot before reserve! can run.
        SlotCapacity.reserve!(capacity_slot.id)

        RecordPlatformEvent.call(
          event_type: "appointment.booked",
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

        appointment
      end
    end

    private

    def validate_booking_inputs!(tenant, citizen, service_type, room, capacity_slot)
      if citizen.municipality_id != tenant.municipality_id ||
         service_type.municipality_id != tenant.municipality_id ||
         room.municipality_id != tenant.municipality_id ||
         capacity_slot.municipality_id != tenant.municipality_id
        Scheduling::Errors::SlotUnavailableError.raise!(:outside_municipality)
      end

      BookingGuards.validate_room_slot_coherence!(room, capacity_slot)
    end

    def validate_citizen_app_facility!(citizen, room)
      return unless @channel == "citizen_app"

      if citizen.health_facility_id.blank?
        Scheduling::Errors::SlotUnavailableError.raise!(:citizen_missing_facility)
      end

      return if citizen.health_facility_id == room.health_facility_id

      Scheduling::Errors::SlotUnavailableError.raise!(:citizen_facility_mismatch)
    end

    def resolve_care_team_id!(tenant, citizen, room)
      team_id = @care_team_id.presence || citizen.care_team_id
      return team_id if team_id.blank?

      if @channel == "citizen_app"
        if team_id.present? && citizen.care_team_id.present? && citizen.care_team_id != team_id
          Scheduling::Errors::SlotUnavailableError.raise!(:care_team_citizen_mismatch)
        end

        return team_id
      end

      team = CareTeam.find_by(id: team_id, municipality_id: tenant.municipality_id)
      unless team && team.health_facility_id == room.health_facility_id
        Scheduling::Errors::SlotUnavailableError.raise!(:care_team_facility_mismatch)
      end

      team.id
    end

    def find_capacity_slot!(room)
      if @room_capacity_slot_id.present?
        slot = SlotCapacity.find_for_booking!(@room_capacity_slot_id)
        Scheduling::Errors::SlotUnavailableError.raise!(:slot_belongs_to_another_room) if slot.consultation_room_id != room.id

        return slot
      end

      date = @scheduled_at.in_time_zone.to_date
      time = @scheduled_at.in_time_zone.strftime("%H:%M:%S")
      slot_id = RoomCapacitySlot.where(
        consultation_room_id: room.id,
        slot_date: date,
        starts_at: time
      ).pick(:id)
      SlotCapacity.find_for_booking!(slot_id)
    end
  end
end
