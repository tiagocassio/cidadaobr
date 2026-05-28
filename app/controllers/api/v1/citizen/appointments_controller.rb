# frozen_string_literal: true

module Api
  module V1
    module Citizen
      class AppointmentsController < BaseController
        def index
          @appointments = Appointment.where(citizen_id: current_citizen.id)
            .includes(:appointment_service_type)
            .order(scheduled_at: :desc)
            .limit(50)
        end

        def slots
          if current_citizen.health_facility_id.blank?
            return render_json_error("Citizen must be linked to a health facility", status: :unprocessable_entity)
          end

          requested_facility_id = params.require(:health_facility_id)
          if requested_facility_id != current_citizen.health_facility_id
            return render_json_error("Citizen is not linked to the selected facility", status: :conflict)
          end

          facility = HealthFacility.find_by!(
            id: current_citizen.health_facility_id,
            municipality_id: current_citizen.municipality_id
          )
          date = parse_slot_date!(params[:date])

          @slots = RoomCapacitySlot
            .where(health_facility_id: facility.id, slot_date: date)
            .where("booked_count < capacity")
            .includes(:consultation_room)
            .order(:starts_at)
        rescue ArgumentError => e
          render_json_error(e.message, status: :unprocessable_entity)
        end

        def create
          if current_citizen.health_facility_id.blank?
            return render_json_error("Citizen must be linked to a health facility before booking", status: :unprocessable_entity)
          end

          scheduled_at = parse_scheduled_at!(params.require(:scheduled_at))
          slot_id = params.require(:room_capacity_slot_id)
          room_id = params.require(:consultation_room_id)
          slot = RoomCapacitySlot.find_by(id: slot_id, health_facility_id: current_citizen.health_facility_id)
          room = ConsultationRoom.find_by(id: room_id, health_facility_id: current_citizen.health_facility_id)
          if slot.nil? || room.nil? || slot.consultation_room_id != room.id
            return render_json_error("Invalid room or slot for citizen facility", status: :unprocessable_entity)
          end

          appointment = Scheduling::BookAppointment.call(
            citizen_id: current_citizen.id,
            appointment_service_type_id: params.require(:appointment_service_type_id),
            consultation_room_id: params.require(:consultation_room_id),
            scheduled_at: scheduled_at,
            room_capacity_slot_id: slot_id,
            channel: "citizen_app"
          )
          @appointment = Appointment.includes(:appointment_service_type).find(appointment.id)
          render :show, status: :created
        rescue Scheduling::Errors::SlotUnavailableError => e
          render_json_error(e.message, status: :conflict)
        rescue ArgumentError => e
          render_json_error(e.message, status: :unprocessable_entity)
        end

        def cancel
          appointment = Appointment.includes(:appointment_service_type).find_by!(id: params[:id], citizen_id: current_citizen.id)
          Scheduling::CancelAppointment.call(appointment: appointment)
          @appointment = appointment.reload
          render :show
        rescue Scheduling::Errors::InvalidTransitionError
          render_json_error("Appointment cannot be cancelled", status: :unprocessable_entity)
        rescue Scheduling::Errors::SlotUnavailableError => e
          render_json_error(e.message, status: :conflict)
        end

        private

        def parse_scheduled_at!(value)
          parsed = Time.zone.parse(value)
          raise ArgumentError, "Invalid scheduled_at" if parsed.nil?

          parsed
        end

        def parse_slot_date!(value)
          return Date.current if value.blank?

          Date.iso8601(value)
        rescue Date::Error, ArgumentError
          raise ArgumentError, "Invalid date"
        end
      end
    end
  end
end
