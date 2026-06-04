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
      citizen_count = citizens.count
      results = []

      scoring_groups(care_team).each do |indicator_code, rules|
        expression = TeamScoreExpression.resolve(indicator_code: indicator_code, rules: rules)
        next unless expression

        score = DslV1::Evaluator.team_score(
          expression: expression,
          citizens: citizens,
          quadrimester: @quadrimester,
          reference_date: @reference_date,
          care_team_id: care_team.id,
          care_team: care_team
        )
        catalog_entry = rules.min_by(&:rule_code).indicator_catalog
        score_scale = expression["score_scale"]
        tier = Scoring.tier_for(score, score_scale: score_scale)
        tier = Scoring.apply_linkage_tier_cap_for_indicator(
          tier,
          indicator_code: indicator_code,
          care_team: care_team,
          citizens: citizens,
          rules: rules,
          citizen_count: citizen_count
        )
        projected_transfer = Scoring.projected_transfer(score, catalog_entry: catalog_entry, score_scale: score_scale)

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
        metadata = result.metadata_json || {}
        pni_release_key = nil
        if indicator_code == "C2"
          pni_release_key = PniScheduleEntry.latest_release_key_for(reference_date: @reference_date)
          metadata = metadata.merge("pni_calendar_release_key" => pni_release_key)
        end
        changed ||= indicator_code == "C2" &&
                     result.metadata_json&.[]("pni_calendar_release_key") != pni_release_key
        result.assign_attributes(score: score, tier: tier, projected_transfer: projected_transfer)
        result.metadata_json = metadata.compact
        result.save!

        emit_team_score_updated!(result) if changed
        results << result
      end

      results
    end

    private

    def scoring_groups(care_team)
      rules = RuleCatalog.rules_for_care_team(care_team, indicator_codes: @indicator_codes)
      rules.group_by { |rule| rule.expression.fetch("indicator_code") }
    end

    def emit_team_score_updated!(result)
      RecordPlatformEvent.call(
        event_type: Cidadaobr::KafkaTopics::INDICATOR_TEAM_SCORE_UPDATED,
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
        care_team_id: result.care_team_id
      )
    end
  end
end
