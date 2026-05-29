# frozen_string_literal: true

module Indicators
  class RecalculateForAppointment < ApplicationCommand
    def initialize(appointment_id:, indicator_codes: nil)
      @appointment_id = appointment_id
      @indicator_codes = indicator_codes
    end

    def call
      tenant = Cidadaobr::TenantContext.current_or_raise!
      # Wrong envelope municipality usually yields RecordNotFound under RLS before this guard runs.
      appointment = Appointment.find(@appointment_id)
      unless appointment.municipality_id == tenant.municipality_id
        raise Indicators::Errors::AppointmentOutsideTenantError,
              "Appointment #{@appointment_id} outside tenant municipality"
      end

      citizen = appointment.citizen
      return { skipped: true } unless citizen

      codes = resolved_indicator_codes
      return { skipped: true } if codes.empty?

      DetectCitizenGaps.call(
        citizen_id: citizen.id,
        indicator_codes: codes,
        reference_date: appointment.scheduled_at.to_date
      )

      if citizen.care_team_id.present?
        RecalculateTeamScore.call(
          care_team_id: citizen.care_team_id,
          indicator_codes: codes,
          reference_date: appointment.scheduled_at.to_date
        )
      end

      { skipped: false, citizen_id: citizen.id, indicator_codes: codes }
    end

    private

    def resolved_indicator_codes
      Array(@indicator_codes).presence || RuleCatalog.appointment_dependent_codes
    end
  end
end
