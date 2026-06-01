# frozen_string_literal: true

module Web
  module Authorizable
    extend ActiveSupport::Concern

    included do
      helper_method :municipality_scope?, :facility_scope?, :team_scope?, :current_municipality if respond_to?(:helper_method)
    end

    private

    def current_municipality
      @current_municipality ||= current_membership&.municipality
    end

    def municipality_scope?
      current_membership&.scope == "municipality"
    end

    def facility_scope?
      current_membership&.scope == "facility"
    end

    def team_scope?
      current_membership&.scope == "team"
    end

    def require_municipality_scope!
      return if municipality_scope?

      redirect_to web_root_path, alert: t("cidadaobr.authorization.municipality_admin_only")
    end

    # Explicit transaction for multi-step writes; RLS SET LOCAL is applied by TenantRlsTransactionExtension.
    def tenant_scoped_transaction(&block)
      ActiveRecord::Base.transaction { yield }
    end

    def require_facility_or_municipality!
      return if municipality_scope? || facility_scope? || current_membership&.scope == "team"

      redirect_to web_root_path, alert: t("cidadaobr.authorization.unauthorized")
    end

    def require_facility_or_municipality_write!
      return if municipality_scope? || facility_scope?

      redirect_to web_root_path, alert: t("cidadaobr.authorization.unauthorized")
    end

    def require_reception_operations!
      return if municipality_scope? || facility_scope? || team_scope?

      redirect_to web_root_path, alert: t("cidadaobr.authorization.unauthorized")
    end

    def scoped_health_facilities
      scope = HealthFacility.where(municipality_id: current_municipality.id)
      return scope if municipality_scope?

      if facility_scope?
        return scope.where(id: current_membership.health_facility_id)
      end

      facility_ids = CareTeam.where(id: current_membership.user.team_ids_for(current_municipality.id))
        .select(:health_facility_id)
      scope.where(id: facility_ids)
    end

    def scoped_care_teams
      scope = CareTeam.where(municipality_id: current_municipality.id)
      return scope if municipality_scope?

      if facility_scope?
        return scope.where(health_facility_id: current_membership.health_facility_id)
      end

      scope.where(id: current_membership.user.team_ids_for(current_municipality.id))
    end

    def scoped_citizens
      scope = Citizen.where(municipality_id: current_municipality.id)
      return scope if municipality_scope?

      if facility_scope?
        return scope_for_health_facility(scope)
      end

      scope.where(care_team_id: current_membership.user.team_ids_for(current_municipality.id))
    end

    def scoped_households
      scope = Household.where(municipality_id: current_municipality.id)
      return scope if municipality_scope?

      if facility_scope?
        return scope_for_health_facility(scope)
      end

      scope.where(care_team_id: current_membership.user.team_ids_for(current_municipality.id))
    end

    def scoped_ledi_batches
      scope = LediBatch.where(municipality_id: current_municipality.id)
      return scope if municipality_scope?

      if facility_scope?
        return scope_for_health_facility(scope)
      end

      scope.where(care_team_id: current_membership.user.team_ids_for(current_municipality.id))
    end

    def scoped_appointments
      scope = Appointment.where(municipality_id: current_municipality.id)
      return scope if municipality_scope?

      if facility_scope?
        return scope.where(health_facility_id: current_membership.health_facility_id)
      end

      scope.where(care_team_id: current_membership.user.team_ids_for(current_municipality.id))
    end

    def scoped_consultation_rooms
      scope = ConsultationRoom.where(municipality_id: current_municipality.id)
      return scope if municipality_scope?

      if facility_scope?
        return scope.where(health_facility_id: current_membership.health_facility_id)
      end

      scope.where(health_facility_id: scoped_health_facilities.select(:id))
    end

    def scoped_team_indicator_results
      scope = TeamIndicatorResult.where(municipality_id: current_municipality.id)
      return scope if municipality_scope?

      team_ids = scoped_care_teams.select(:id)
      scope.where(care_team_id: team_ids)
    end

    def scoped_citizen_indicator_gaps
      scope = CitizenIndicatorGap.where(municipality_id: current_municipality.id)
      return scope if municipality_scope?

      team_ids = scoped_care_teams.select(:id)
      scope.where(care_team_id: team_ids)
    end

    def scope_for_health_facility(scope)
      facility_id = current_membership.health_facility_id
      team_ids = CareTeam.where(municipality_id: current_municipality.id, health_facility_id: facility_id).select(:id)

      scope.where(health_facility_id: facility_id).or(scope.where(care_team_id: team_ids))
    end

    def sanitize_scoped_health_facility_id(facility_id)
      if facility_scope?
        current_membership.health_facility_id
      elsif facility_id.present?
        scoped_health_facilities.find_by(id: facility_id)&.id
      end
    end

    def invalid_scoped_health_facility_param?(facility_id)
      return false if facility_scope?
      return true if facility_id.blank?

      !scoped_health_facilities.exists?(id: facility_id)
    end

    def sanitize_scoped_consultation_room_id(room_id, health_facility_id:)
      return if room_id.blank?

      scope = scoped_consultation_rooms.where(id: room_id)
      scope = scope.where(health_facility_id: health_facility_id) if health_facility_id.present?
      scope.pick(:id)
    end

    def invalid_scoped_consultation_room_param?(room_id, health_facility_id:)
      return false if room_id.blank?
      return true if health_facility_id.blank?

      sanitize_scoped_consultation_room_id(room_id, health_facility_id: health_facility_id).nil?
    end

    def add_scoped_param_errors(record, raw_facility_id:, raw_room_id: nil, health_facility_id: nil)
      invalid = false
      if invalid_scoped_health_facility_param?(raw_facility_id)
        record.errors.add(:health_facility_id, :invalid)
        invalid = true
      end
      if invalid_scoped_consultation_room_param?(raw_room_id, health_facility_id: health_facility_id)
        record.errors.add(:consultation_room_id, :invalid)
        invalid = true
      end
      invalid
    end
  end
end
