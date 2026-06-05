# frozen_string_literal: true

module CitizenPortal
  module CareTeamRouting
    module_function

    # Routing hint for platform events when the citizen has no direct care team.
    # UBS with multiple teams: one stable hint (lowest id); team-scope RLS still matches any
    # team at the same facility — Kafka consumers must not treat this as exclusive ownership.
    def resolve_care_team_id(citizen)
      return citizen.care_team_id if citizen&.care_team_id.present?
      return nil unless citizen&.health_facility_id.present?

      CareTeam.where(
        municipality_id: citizen.municipality_id,
        health_facility_id: citizen.health_facility_id
      ).order(:id).pick(:id)
    end
  end
end
