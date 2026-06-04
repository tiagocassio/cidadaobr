# frozen_string_literal: true

class RecalculatePniReleaseJob < ApplicationJob
  queue_as :default

  discard_on ActiveRecord::RecordNotFound

  def perform(municipality_id:, reference_date: Date.current.iso8601, indicator_codes: %w[C2])
    municipality = Municipality.find(municipality_id)
    reference_date = Date.iso8601(reference_date.to_s)
    quadrimester = Indicators::Quadrimester.current(reference_date)
    indicator_codes = Array(indicator_codes)

    tenant = Cidadaobr::TenantScope.new(
      municipality_id: municipality.id,
      scope: "municipality",
      health_facility_id: nil,
      team_ids: [],
      citizen_id: nil
    )
    Cidadaobr::TenantContext.with(tenant) do
      CareTeam.where(municipality_id: municipality.id).find_each(batch_size: 100) do |care_team|
        CommandBus.dispatch(
          Indicators::RecalculateTeamScore,
          care_team_id: care_team.id,
          quadrimester: quadrimester,
          reference_date: reference_date,
          indicator_codes: indicator_codes
        )
      end
    end
  end
end
