# frozen_string_literal: true

module Cidadaobr
  TenantScope = Data.define(:municipality_id, :scope, :health_facility_id, :team_ids, :citizen_id) do
    def self.from_membership(membership)
      new(
        municipality_id: membership.municipality_id,
        scope: membership.scope,
        health_facility_id: membership.health_facility_id,
        team_ids: membership.user.team_ids_for(membership.municipality_id),
        citizen_id: nil
      )
    end

    def self.from_citizen_account(account)
      new(
        municipality_id: account.municipality_id,
        scope: "citizen",
        health_facility_id: nil,
        team_ids: [],
        citizen_id: account.citizen_id
      )
    end

    def self.from_envelope(envelope)
      municipality_id = envelope.fetch("municipality_id")
      health_facility_id = envelope["health_facility_id"].presence
      care_team_id = envelope["care_team_id"].presence
      scope =
        if care_team_id.present?
          "team"
        elsif health_facility_id.present?
          "facility"
        else
          "municipality"
        end

      new(
        municipality_id: municipality_id,
        scope: scope,
        health_facility_id: health_facility_id,
        team_ids: care_team_id.present? ? [ care_team_id ] : [],
        citizen_id: envelope["citizen_id"].presence
      )
    end
  end
end
