# frozen_string_literal: true

require "rails_helper"

RSpec.describe Indicators::CoverageAudit do
  before { load Rails.root.join("db/seeds/indicator_catalog.rb") }

  it "reports pack and resolver coverage with DB alignment" do
    report = described_class.full_report

    expect(report["packs_defined"]).to be >= 40
    expect(report["packs_on_disk"]).to eq(report["packs_defined"])
    expect(report["resolver_types"].keys).to include(:citizen_scope, :clinical_evidence, :team_score_modes)
    expect(report["missing_resolvers"]).to eq([])
    expect(report["pack_drift"]).to eq([])
    expect(described_class.misaligned_bp_coverage(report)).to eq([])
    expect(report["bp_coverage"]).to include(
      include("indicator" => "C4", "pack_rules" => 6, "db_rules" => 6, "aligned" => true)
    )
  end

  it "flags empty on-disk packs as drift" do
    drift = described_class.pack_drift_report(
      Indicators::MethodologyPackDefinitions.all.first(1),
      []
    )

    expect(drift).to include(a_string_matching(/missing_on_disk: all/))
  end

  it "detects expression drift between packs and DB rules" do
    rule = IndicatorRule.joins(:indicator_catalog).find_by!(indicator_catalog: { code: "C1" })
    rule.update!(expression: rule.expression.merge("team_score_mode" => "procedure_ratio"))

    report = described_class.full_report
    c1 = report["bp_coverage"].find { |row| row["indicator"] == "C1" }

    expect(c1["aligned"]).to be(false)
    expect(c1["expression_drift"]).to include(rule.rule_code)
  end

  it "reports invalid on-disk pack JSON in pack_drift without aborting" do
    allow(described_class).to receive(:load_disk_packs).and_wrap_original do |method|
      result = method.call
      result.merge(
        invalid: result.fetch(:invalid) + [ "invalid_json: broken.json(unexpected token)" ],
        unreadable: result.fetch(:unreadable) + [ "broken.json" ]
      )
    end

    report = described_class.full_report

    expect(report["pack_drift"]).to include(a_string_matching(/invalid_json: broken\.json/))
    expect(report["pack_drift"]).to include(a_string_matching(/unreadable_on_disk: broken\.json/))
  end
end
