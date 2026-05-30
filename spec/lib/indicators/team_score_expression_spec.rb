# frozen_string_literal: true

require "rails_helper"

RSpec.describe Indicators::TeamScoreExpression do
  let(:expression) { { "version" => "dsl_v1", "indicator_code" => "C4" } }
  let(:rule) { instance_double(IndicatorRule, expression: expression) }

  it "returns explicit team_score_mode when present" do
    explicit = rule
    allow(explicit).to receive(:expression).and_return(expression.merge("team_score_mode" => "programmed_attendance_ratio"))

    resolved = described_class.resolve(indicator_code: "C1", rules: [ explicit ])

    expect(resolved["team_score_mode"]).to eq("programmed_attendance_ratio")
  end

  it "returns good_practices_pct synthetic expression for multi-rule indicators" do
    resolved = described_class.resolve(indicator_code: "C4", rules: [ rule, rule ])

    expect(resolved).to eq(
      "version" => "dsl_v1",
      "indicator_code" => "C4",
      "team_score_mode" => "good_practices_pct"
    )
  end

  it "returns fallback when no scoring rules apply" do
    fallback = { "version" => "dsl_v1", "indicator_code" => "V_CAD" }
    skipped = instance_double(IndicatorRule, expression: fallback.merge("skip_team_score" => true))

    resolved = described_class.resolve(indicator_code: "V_CAD", rules: [ skipped ], fallback_expression: fallback)

    expect(resolved).to eq(fallback)
  end
end
