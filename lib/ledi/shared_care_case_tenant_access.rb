# frozen_string_literal: true

module Ledi
  module SharedCareCaseTenantAccess
    module_function

    def accessible?(shared_care_case, tenant)
      return false if shared_care_case.municipality_id != tenant.municipality_id

      case tenant.scope
      when "municipality"
        true
      when "team"
        team_accessible?(shared_care_case, tenant.team_ids)
      when "facility"
        tenant.health_facility_id.present? &&
          facility_accessible?(shared_care_case, tenant.health_facility_id)
      else
        false
      end
    end

    def citizen_accessible?(citizen, tenant)
      return false if citizen.municipality_id != tenant.municipality_id

      case tenant.scope
      when "municipality"
        true
      when "team"
        citizen_team_accessible?(citizen, tenant.team_ids)
      when "facility"
        tenant.health_facility_id.present? &&
          citizen_facility_accessible?(citizen, tenant.health_facility_id)
      else
        false
      end
    end

    def team_accessible?(shared_care_case, team_ids)
      return false if team_ids.blank?

      team_id_strings = team_ids.map(&:to_s)
      origin = shared_care_case.origin_care_team_id
      return true if origin.present? && team_id_strings.include?(origin.to_s)

      citizen_team_accessible?(shared_care_case.citizen, team_ids)
    end

    def facility_accessible?(shared_care_case, facility_id)
      origin = shared_care_case.origin_care_team_id
      if origin.present?
        return CareTeam.where(id: origin, health_facility_id: facility_id).exists?
      end

      citizen_facility_accessible?(shared_care_case.citizen, facility_id)
    end

    def citizen_team_accessible?(citizen, team_ids)
      return false if citizen.nil? || team_ids.blank?

      team_id_strings = team_ids.map(&:to_s)
      return true if citizen.care_team_id.present? && team_id_strings.include?(citizen.care_team_id.to_s)
      return false if citizen.health_facility_id.blank?

      CareTeam.where(id: team_ids, health_facility_id: citizen.health_facility_id).exists?
    end

    def citizen_facility_accessible?(citizen, facility_id)
      return false unless citizen

      return true if citizen.health_facility_id == facility_id

      citizen.care_team_id.present? &&
        CareTeam.where(id: citizen.care_team_id, health_facility_id: facility_id).exists?
    end

    def care_team_accessible?(team, tenant)
      return false if team.municipality_id != tenant.municipality_id

      case tenant.scope
      when "municipality"
        true
      when "facility"
        team.health_facility_id == tenant.health_facility_id
      when "team"
        tenant.team_ids.map(&:to_s).include?(team.id.to_s)
      else
        false
      end
    end
  end
end
