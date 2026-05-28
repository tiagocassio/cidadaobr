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
  end
end
