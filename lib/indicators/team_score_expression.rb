# frozen_string_literal: true

module Indicators
  # Shared team-score expression selection for RecalculateTeamScore and linkage child scores.
  module TeamScoreExpression
    module_function

    def resolve(indicator_code:, rules:, fallback_expression: nil)
      scoring_rules = Array(rules).reject { |rule| rule.expression["skip_team_score"] }
      return fallback_expression if scoring_rules.empty?

      explicit = scoring_rules.find { |rule| rule.expression["team_score_mode"].present? }
      return explicit.expression if explicit

      if scoring_rules.size > 1
        return {
          "version" => "dsl_v1",
          "indicator_code" => indicator_code,
          "team_score_mode" => "good_practices_pct"
        }
      end

      scoring_rules.first.expression
    end
  end
end
