# frozen_string_literal: true

module Indicators
  # Official nomenclature from Portaria GM/MS 3.493/2024 and SAPS 161/2024.
  # Storage uses en-US underscores (V_CAD_COM); MS documents use hyphens (V-CAD-COM).
  module Portaria3493
    INDICATOR_CODES = %w[
      CVAT V_CAD V_ACOMP V_SAT
      C1 C2 C3 C4 C5 C6 C7
      B1 B2 B3 B4 B5 B6
      M1 M2
    ].freeze

    # Linkage rule codes (NT 30/2025 / Portaria SAPS 161/2024): V-CAD-COM, V-CAD-ATU, V-ACOMP-12M, V-LIM-CAD.
    LINKAGE_RULE_CODES = %w[
      V_CAD_ATU
      V_CAD_COM
      V_ACOMP_12M
      V_LIM_CAD
    ].freeze

    # Quality good practices (Notas Metodológicas C1–C7): BP A–K
    QUALITY_BP_LETTERS = ("A".."K").to_a.freeze

    TEAM_INDICATOR_CODES = %w[B1 B2 B3 B4 B5 B6 M1 M2].freeze

    # Team indicators (B1–M2) reuse indicator_catalog.code as good_practice_code in seed DSL expressions.
    GOOD_PRACTICE_CODES = (
      LINKAGE_RULE_CODES +
      QUALITY_BP_LETTERS +
      TEAM_INDICATOR_CODES +
      %w[V_SAT]
    ).freeze

    module_function

    def known_indicator_code?(code)
      INDICATOR_CODES.include?(code.to_s)
    end

    def known_good_practice_code?(code)
      GOOD_PRACTICE_CODES.include?(code.to_s)
    end
  end
end
