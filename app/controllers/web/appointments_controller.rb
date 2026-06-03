# frozen_string_literal: true

module Web
  class AppointmentsController < BaseController
    before_action :require_facility_or_municipality!
    before_action :require_facility_or_municipality_write!, only: %i[new create reschedule walk_in]
    before_action :require_reception_operations!, only: %i[check_in complete cancel no_show reschedule walk_in]
    before_action :ensure_health_facility_selected!, only: %i[index reception utilization new create walk_in]
    before_action :set_appointment, only: %i[show check_in complete cancel no_show reschedule]
    before_action :set_form_collections, only: %i[new create walk_in]

    helper_method :facility_scope_params

    def index
      @date = schedule_date
      @schedule = Scheduling::FacilityDailySchedule.new(
        health_facility_id: selected_facility_id,
        date: @date
      ).call
    end

    def show
      if @appointment.status.in?(%w[scheduled confirmed])
        @reschedule_slots = RoomCapacitySlot
          .where(
            health_facility_id: @appointment.health_facility_id,
            consultation_room_id: @appointment.consultation_room_id,
            slot_date: @appointment.scheduled_at.to_date
          )
          .where("booked_count < capacity")
          .includes(:consultation_room)
          .order(:starts_at)
      end
    end

    def select_facility
      @health_facilities = scoped_health_facilities.order(:name)
    end

    def new
      @appointment = Appointment.new(scheduled_at: Time.zone.now.change(min: 0))
    end

    def create
      attrs = appointment_params
      slot = scoped_capacity_slots.find(attrs.fetch(:room_capacity_slot_id))
      room = scoped_consultation_rooms.find(attrs.fetch(:consultation_room_id))
      citizen = scoped_citizens.find(attrs.fetch(:citizen_id))
      if slot.consultation_room_id != room.id || room.health_facility_id != selected_facility_id
        raise ArgumentError, "invalid slot or room for facility"
      end

      scheduled_at = Time.zone.parse("#{slot.slot_date} #{slot.starts_at.strftime('%H:%M:%S')}")

      appointment = CommandBus.dispatch(
        Scheduling::BookAppointment,
        citizen_id: citizen.id,
        appointment_service_type_id: attrs.fetch(:appointment_service_type_id),
        consultation_room_id: room.id,
        scheduled_at: scheduled_at,
        room_capacity_slot_id: slot.id,
        care_team_id: attrs[:care_team_id],
        channel: "web_reception"
      )
      redirect_to web_appointment_path(appointment), notice: t("cidadaobr.appointments.flash.booked")
    rescue Scheduling::Errors::SlotUnavailableError => e
      flash.now[:alert] = Scheduling::ErrorMessages.slot_unavailable_message(e)
      render_new_with_errors
    rescue ActiveRecord::RecordNotFound, ArgumentError
      flash.now[:alert] = t("cidadaobr.appointments.flash.invalid_booking_data")
      render_new_with_errors
    end

    def reception
      @appointments = scoped_appointments
        .where(health_facility_id: selected_facility_id, status: %w[checked_in scheduled confirmed])
        .includes(:citizen, :appointment_service_type)
        .order(:scheduled_at)
    end

    def utilization
      @from_date, @to_date = utilization_date_range
      @report = Scheduling::FacilityUtilizationReport.new(
        health_facility_id: selected_facility_id,
        from_date: @from_date,
        to_date: @to_date
      ).call
    end

    def walk_in
      @appointment = Appointment.new
      return if request.get?

      attrs = walk_in_params
      room = scoped_consultation_rooms.find(attrs.fetch(:consultation_room_id))
      citizen = scoped_citizens.find(attrs.fetch(:citizen_id))

      appointment = CommandBus.dispatch(
        Scheduling::BookWalkInAppointment,
        citizen_id: citizen.id,
        appointment_service_type_id: attrs.fetch(:appointment_service_type_id),
        consultation_room_id: room.id,
        care_team_id: attrs[:care_team_id]
      )
      redirect_to reception_web_appointments_path(facility_scope_params(room.health_facility_id)),
                  notice: t("cidadaobr.appointments.flash.walk_in_booked")
    rescue Scheduling::Errors::SlotUnavailableError => e
      flash.now[:alert] = Scheduling::ErrorMessages.slot_unavailable_message(e)
      @appointment = Appointment.new(attrs)
      render :walk_in, status: :unprocessable_entity
    rescue ActiveRecord::RecordNotFound, ArgumentError
      flash.now[:alert] = t("cidadaobr.appointments.flash.invalid_booking_data")
      @appointment = Appointment.new(walk_in_params)
      render :walk_in, status: :unprocessable_entity
    end

    def check_in
      CommandBus.dispatch(Scheduling::CheckInAppointment, appointment: @appointment)
      redirect_to_reception_for(@appointment, notice: t("cidadaobr.appointments.flash.check_in"))
    rescue Scheduling::Errors::InvalidTransitionError
      redirect_to_reception_for(@appointment, alert: t("cidadaobr.appointments.flash.check_in_failed"))
    end

    def complete
      CommandBus.dispatch(Scheduling::CompleteAppointment, appointment: @appointment)
      redirect_to_reception_for(@appointment, notice: t("cidadaobr.appointments.flash.completed"))
    rescue Scheduling::Errors::InvalidTransitionError
      redirect_to_reception_for(@appointment, alert: t("cidadaobr.appointments.flash.complete_failed"))
    end

    def cancel
      CommandBus.dispatch(Scheduling::CancelAppointment, appointment: @appointment)
      redirect_to web_appointments_path(facility_scope_params(@appointment.health_facility_id)), notice: t("cidadaobr.appointments.flash.cancelled")
    rescue Scheduling::Errors::InvalidTransitionError
      redirect_to web_appointment_path(@appointment), alert: t("cidadaobr.appointments.flash.cancel_failed")
    rescue Scheduling::Errors::SlotUnavailableError => e
      redirect_to web_appointment_path(@appointment), alert: Scheduling::ErrorMessages.slot_unavailable_message(e)
    end

    def no_show
      CommandBus.dispatch(Scheduling::MarkAppointmentNoShow, appointment: @appointment)
      redirect_to_reception_for(@appointment, notice: t("cidadaobr.appointments.flash.no_show"))
    rescue Scheduling::Errors::InvalidTransitionError
      redirect_to_reception_for(@appointment, alert: t("cidadaobr.appointments.flash.no_show_failed"))
    rescue Scheduling::Errors::SlotUnavailableError => e
      redirect_to_reception_for(@appointment, alert: Scheduling::ErrorMessages.slot_unavailable_message(e))
    end

    def reschedule
      slot = RoomCapacitySlot.find_by!(
        id: params.require(:room_capacity_slot_id),
        health_facility_id: @appointment.health_facility_id,
        consultation_room_id: @appointment.consultation_room_id
      )
      scheduled_at = Time.zone.parse("#{slot.slot_date} #{slot.starts_at.strftime('%H:%M:%S')}")

      CommandBus.dispatch(
        Scheduling::RescheduleAppointment,
        appointment: @appointment,
        scheduled_at: scheduled_at,
        room_capacity_slot_id: slot.id
      )
      redirect_to web_appointment_path(@appointment), notice: t("cidadaobr.appointments.flash.rescheduled")
    rescue Scheduling::Errors::InvalidTransitionError
      redirect_to web_appointment_path(@appointment), alert: t("cidadaobr.appointments.flash.reschedule_failed")
    rescue Scheduling::Errors::SlotUnavailableError => e
      redirect_to web_appointment_path(@appointment), alert: Scheduling::ErrorMessages.slot_unavailable_message(e)
    rescue ActiveRecord::RecordNotFound, ArgumentError
      redirect_to web_appointment_path(@appointment), alert: t("cidadaobr.appointments.flash.invalid_reschedule_data")
    end

    private

    def set_appointment
      @appointment = scoped_appointments.find(params[:id])
    end

    def set_form_collections
      @citizens = scoped_citizens.order(:full_name).limit(200)
      @service_types = AppointmentServiceType.where(municipality_id: current_municipality.id, active: true).order(:name)
      @rooms = scoped_consultation_rooms.where(health_facility_id: selected_facility_id, active: true).order(:name)
      slot_date = appointment_slot_date
      @capacity_slots = RoomCapacitySlot
        .where(health_facility_id: selected_facility_id, slot_date: slot_date)
        .where("booked_count < capacity")
        .includes(:consultation_room)
        .order(:starts_at)
    rescue Date::Error, ArgumentError
      @capacity_slots = RoomCapacitySlot.none
    end

    def schedule_date
      return Date.current if params[:date].blank?

      Date.iso8601(params[:date])
    rescue Date::Error, ArgumentError
      Date.current
    end

    def utilization_date_range
      filter = params.permit(:from_date, :to_date, :health_facility_id)
      from = parse_date_param(filter[:from_date], default: Date.current.beginning_of_month)
      to = parse_date_param(filter[:to_date], default: Date.current)
      to = from if to < from
      [ from, to ]
    end

    def parse_date_param(value, default:)
      return default if value.blank?

      Date.iso8601(value)
    rescue Date::Error, ArgumentError
      default
    end

    def ensure_health_facility_selected!
      return unless municipality_scope? || team_scope?
      return if params[:health_facility_id].present?

      facilities = scoped_health_facilities.order(:name)
      if facilities.one?
        redirect_to url_for(facility_scope_params(facilities.first!.id))
        return
      end

      @health_facilities = facilities
      render :select_facility
    end

    def selected_facility_id
      if facility_scope?
        current_membership.health_facility_id
      else
        resolve_scoped_health_facility_id!
      end
    end

    def resolve_scoped_health_facility_id!
      facilities = scoped_health_facilities
      facility_id = params[:health_facility_id].presence
      return facilities.find(facility_id).id if facility_id.present?

      if facilities.one?
        return facilities.first!.id
      end

      raise ArgumentError, "health_facility_id is required"
    end

    def facility_scope_params(facility_id = selected_facility_id)
      return {} if facility_scope?

      { health_facility_id: facility_id }
    end

    def scoped_capacity_slots
      RoomCapacitySlot.where(health_facility_id: selected_facility_id)
    end

    def appointment_params
      attrs = params.expect(
        appointment: %i[
          citizen_id
          appointment_service_type_id
          consultation_room_id
          room_capacity_slot_id
        ]
      )
      merge_optional_appointment_params(attrs)
    end

    def appointment_slot_date
      return Date.current unless params.key?(:appointment)

      slot_date = params.permit(appointment: [ :slot_date ])[:appointment]&.dig(:slot_date)
      parse_date_param(slot_date, default: Date.current)
    end

    def walk_in_params
      attrs = params.expect(
        appointment: %i[
          citizen_id
          appointment_service_type_id
          consultation_room_id
        ]
      )
      merge_optional_appointment_params(attrs)
    end

    def merge_optional_appointment_params(attrs)
      optional = params.permit(appointment: %i[care_team_id slot_date])[:appointment]
      attrs[:care_team_id] = optional[:care_team_id] if optional&.key?(:care_team_id)
      attrs
    end

    def render_new_with_errors
      attrs = params.permit(
        appointment: %i[
          citizen_id
          appointment_service_type_id
          consultation_room_id
          room_capacity_slot_id
          care_team_id
          slot_date
        ]
      )[:appointment] || {}
      @appointment = Appointment.new(attrs.except(:room_capacity_slot_id))
      @selected_room_capacity_slot_id = attrs[:room_capacity_slot_id]
      set_form_collections
      render :new, status: :unprocessable_entity
    end

    def redirect_to_reception_for(appointment, notice: nil, alert: nil)
      redirect_to reception_web_appointments_path(facility_scope_params(appointment.health_facility_id)), notice: notice, alert: alert
    end
  end
end
