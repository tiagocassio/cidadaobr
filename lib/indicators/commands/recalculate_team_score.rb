# frozen_string_literal: true

module Indicators
  class RecalculateTeamScore < ApplicationCommand
    def initialize(care_team_id:, indicator_codes: nil, quadrimester: nil, reference_date: Date.current)
      @care_team_id = care_team_id
      @indicator_codes = indicator_codes
      @quadrimester = quadrimester || Quadrimester.current(reference_date)
      @reference_date = reference_date
    end

    def call
      tenant = Cidadaobr::TenantContext.current_or_raise!
      care_team = CareTeam.find(@care_team_id)
      raise ActiveRecord::RecordNotFound unless care_team.municipality_id == tenant.municipality_id

      citizens = Citizen.where(municipality_id: tenant.municipality_id, care_team_id: care_team.id)
      results = []

      rules_for_team(care_team).each do |rule|
        expression = rule.expression
        indicator_code = expression.fetch("indicator_code")
        score = DslV1::Evaluator.team_score(
          expression: expression,
          citizens: citizens,
          quadrimester: @quadrimester,
          reference_date: @reference_date
        )
        tier = Scoring.tier_for(score)
        projected_transfer = Scoring.projected_transfer(score, catalog_entry: rule.indicator_catalog)

        result = TeamIndicatorResult.find_or_initialize_by(
          municipality_id: tenant.municipality_id,
          care_team_id: care_team.id,
          indicator_code: indicator_code,
          quadrimester: @quadrimester
        )
        changed = result.new_record? ||
                  result.score.to_f != score.to_f ||
                  result.tier != tier ||
                  result.projected_transfer.to_f != projected_transfer.to_f
        result.assign_attributes(score: score, tier: tier, projected_transfer: projected_transfer)
        result.save!

        emit_team_score_updated!(result) if changed
        results << result
      end

      results
    end

    private

    def rules_for_team(_care_team)
      RuleCatalog.dsl_v1_rules(
        indicator_codes: @indicator_codes,
        team_kinds: [ "esf", "municipality", nil ]
      )
    end

    def emit_team_score_updated!(result)
      RecordPlatformEvent.call(
        event_type: "indicator.team_score.updated",
        aggregate_type: "TeamIndicatorResult",
        aggregate_id: result.id,
        payload: {
          team_indicator_result_id: result.id,
          care_team_id: result.care_team_id,
          indicator_code: result.indicator_code,
          quadrimester: result.quadrimester,
          score: result.score,
          tier: result.tier,
          projected_transfer: result.projected_transfer
        },
        topic: OutboxPublisher::TOPIC_MAPPING.fetch("indicator.team_score.updated"),
        care_team_id: result.care_team_id
      )
    end
  end
end
