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

    module_function

    def tier_for(score)
      value = score.to_f
      case value
      when 85..100 then "excellent"
      when 65...85 then "good"
      when 45...65 then "sufficient"
      else "regular"
      end
    end

    def projected_transfer(score, catalog_entry:)
      team_kind = catalog_entry.team_kind.presence || "esf"
      component = catalog_entry.funding_component
      base = repasse_coefficients.fetch(team_kind, {}).fetch(component, 0.0)
      return 0.0 if base.zero?

      (base * (score.to_f / 100.0)).round(2)
    end

    def repasse_coefficients
      @repasse_coefficients ||= load_repasse_coefficients
    end

    def load_repasse_coefficients
      path = Rails.root.join("config/indicators/repasse_coefficients.yml")
      return COMPONENT_BASE_BRL unless path.exist?

      data = YAML.safe_load(path.read, permitted_classes: [], aliases: true)
      data.is_a?(Hash) ? data : COMPONENT_BASE_BRL
    rescue StandardError
      COMPONENT_BASE_BRL
    end

    def projected_transfer_stub(score, team_kind: "esf", catalog_entry: nil)
      if catalog_entry
        projected_transfer(score, catalog_entry: catalog_entry)
      else
        base = team_kind == "esf" ? 12_000.0 : 8_000.0
        (base * (score.to_f / 100.0)).round(2)
      end
    end
  end
end
