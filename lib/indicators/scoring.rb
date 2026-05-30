# frozen_string_literal: true

module Indicators
  module Scoring
    # Illustrative MVP weights only — not official Portaria repasse tables. Do not use for financial reporting.
    COMPONENT_BASE_BRL = {
      "esf" => {
        "fixed" => 3_000.0,
        "linkage" => 5_000.0,
        "quality" => 7_000.0,
        "implementation" => 1_500.0,
        "zoonoses" => 500.0
      },
      "esb" => {
        "quality" => 4_000.0,
        "implementation" => 1_000.0
      },
      "emulti" => {
        "quality" => 3_500.0,
        "implementation" => 1_000.0
      },
      "municipality" => {
        "fixed" => 2_000.0,
        "linkage" => 3_000.0,
        "quality" => 4_000.0
      }
    }.freeze

    TIER_RANK = { "regular" => 0, "sufficient" => 1, "good" => 2, "excellent" => 3 }.freeze

    LINKAGE_CAP_INDICATOR = "V_CAD"

    module_function

    def tier_for(score, score_scale: nil)
      value = score.to_f
      scale = score_scale.to_s
      if scale == "ms_0_10"
        case value
        when 8.5..10.0 then "excellent"
        when 6.5...8.5 then "good"
        when 4.5...6.5 then "sufficient"
        else "regular"
        end
      else
        case value
        when 85..100 then "excellent"
        when 65...85 then "good"
        when 45...65 then "sufficient"
        else "regular"
        end
      end
    end

    def apply_linkage_tier_cap(tier, rules:, citizens:, citizen_count: nil)
      cap_rule = rules.find { |rule| rule.expression["caps_linkage_tier"].present? }
      return tier unless cap_rule

      limit = cap_rule.expression.dig("numerator", "team_limit") || 3_500
      count = citizen_count || citizens.count
      return tier if count <= limit.to_i

      max_tier = cap_rule.expression.fetch("caps_linkage_tier")
      return tier if TIER_RANK.fetch(tier, 0) <= TIER_RANK.fetch(max_tier, 2)

      max_tier
    end

    def linkage_cap_rule_for(care_team)
      rules = RuleCatalog.dsl_v1_rules(indicator_codes: [ LINKAGE_CAP_INDICATOR ])
      rules = rules.select { |rule| RuleCatalog.rule_applies_to_care_team?(rule, care_team) }
      rules.find { |rule| rule.expression["caps_linkage_tier"].present? }
    end

    def apply_linkage_tier_cap_for_indicator(tier, indicator_code:, care_team:, citizens:, rules:, citizen_count: nil)
      cap_rule = rules.find { |rule| rule.expression["caps_linkage_tier"].present? }
      cap_rule ||= linkage_cap_rule_for(care_team) if indicator_code == "CVAT"
      return tier unless cap_rule

      apply_linkage_tier_cap(tier, rules: [ cap_rule ], citizens: citizens, citizen_count: citizen_count)
    end

    def projected_transfer(score, catalog_entry:, score_scale: nil)
      team_kind = catalog_entry.team_kind.presence || "esf"
      component = catalog_entry.funding_component
      base = repasse_coefficients.fetch(team_kind, {}).fetch(component, 0.0)
      return 0.0 if base.zero?

      divisor = score_scale.to_s == "ms_0_10" ? 10.0 : 100.0
      (base * (score.to_f / divisor)).round(2)
    end

    def repasse_coefficients
      @repasse_coefficients ||= load_repasse_coefficients
    end

    def load_repasse_coefficients
      path = Rails.root.join("config/indicators/repasse_coefficients.yml")
      return COMPONENT_BASE_BRL unless path.exist?

      data = YAML.safe_load(path.read, permitted_classes: [], aliases: true)
      return COMPONENT_BASE_BRL unless data.is_a?(Hash)

      data
    rescue Psych::SyntaxError => error
      Rails.logger.warn("[Indicators::Scoring] repasse coefficients load failed: #{error.message}")
      COMPONENT_BASE_BRL
    end

    def projected_transfer_stub(score, team_kind: "esf", catalog_entry: nil, score_scale: nil)
      if catalog_entry
        projected_transfer(score, catalog_entry: catalog_entry, score_scale: score_scale)
      else
        base = team_kind == "esf" ? 12_000.0 : 8_000.0
        divisor = score_scale.to_s == "ms_0_10" ? 10.0 : 100.0
        (base * (score.to_f / divisor)).round(2)
      end
    end
  end
end
