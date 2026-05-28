# frozen_string_literal: true

module Web
  module Authorizable
    extend ActiveSupport::Concern

    included do
      helper_method :municipality_scope?, :facility_scope?, :current_municipality if respond_to?(:helper_method)
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

    def require_municipality_scope!
      return if municipality_scope?

      redirect_to web_root_path, alert: "Acesso restrito a administradores municipais."
    end

    def require_facility_or_municipality!
      return if municipality_scope? || facility_scope? || current_membership&.scope == "team"

      redirect_to web_root_path, alert: "Acesso não autorizado."
    end

    def require_facility_or_municipality_write!
      return if municipality_scope? || facility_scope?

      redirect_to web_root_path, alert: "Acesso não autorizado."
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

    def scope_for_health_facility(scope)
      facility_id = current_membership.health_facility_id
      team_ids = CareTeam.where(municipality_id: current_municipality.id, health_facility_id: facility_id).select(:id)

      scope.where(health_facility_id: facility_id).or(scope.where(care_team_id: team_ids))
    end
  end
end
