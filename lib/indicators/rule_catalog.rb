# frozen_string_literal: true

module Indicators
  module RuleCatalog
    APPOINTMENT_CLAUSE_TYPE = "appointment_in_quadrimester"
    # When CareTeam has no team_kind, only catalog rules for these kinds are evaluated.
    FALLBACK_TEAM_KINDS_FOR_UNKNOWN_CARE_TEAM = %w[esf municipality].freeze

    module_function

    def rule_applies_to_care_team?(rule, care_team)
      required = rule.indicator_catalog.team_kind
      return true if required.blank?

      inferred = care_team.try(:team_kind)
      if inferred.present?
        return inferred == required
      end

      FALLBACK_TEAM_KINDS_FOR_UNKNOWN_CARE_TEAM.include?(required)
    end

    def rules_for_care_team(care_team, indicator_codes: nil)
      dsl_v1_rules(indicator_codes: indicator_codes).select do |rule|
        rule_applies_to_care_team?(rule, care_team)
      end
    end

    def evaluable_indicator_codes(codes, care_team: nil)
      return [] if codes.blank?

      rules = dsl_v1_rules(indicator_codes: codes)
      rules = rules.select { |rule| rule_applies_to_care_team?(rule, care_team) } if care_team.present?
      rules.filter_map { |rule| rule.expression["indicator_code"] }.uniq
    end

    def dsl_v1_rules(indicator_codes: nil, team_kinds: nil)
      scope = IndicatorRule.includes(:indicator_catalog).joins(:indicator_catalog).merge(IndicatorCatalog.active_portaria)
      scope = scope.where(indicator_catalog: { code: Array(indicator_codes) }) if indicator_codes.present?
      scope = scope.where(indicator_catalog: { team_kind: team_kinds }) if team_kinds

      scope.select { |rule| DslV1::Evaluator.dsl_v1?(rule.expression) }
    end

    def appointment_dependent_codes
      dsl_v1_rules.filter_map do |rule|
        expression = rule.expression
        next unless references_appointments?(expression["numerator"]) || references_appointments?(expression["denominator"])

        expression["indicator_code"]
      end.uniq
    end

    def references_appointments?(clause)
      return false if clause.blank?
      return true if clause.is_a?(Hash) && clause["type"] == APPOINTMENT_CLAUSE_TYPE
      return false unless clause.is_a?(Hash)

      clause.values.any? { |value| references_appointments_in?(value) }
    end

    def references_appointments_in?(value)
      case value
      when Hash then references_appointments?(value)
      when Array then value.any? { |item| references_appointments_in?(item) }
      else false
      end
    end
  end
end
