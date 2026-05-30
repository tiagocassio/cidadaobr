# frozen_string_literal: true

require "rails_helper"

RSpec.describe Indicators::Scoring do
  it "loads repasse coefficients from config when present" do
    expect(described_class.repasse_coefficients.dig("esf", "linkage")).to eq(5_000.0)
  end

  it "projects transfer from catalog entry and score" do
    catalog = IndicatorCatalog.new(code: "V_CAD", funding_component: "linkage", team_kind: "esf")
    amount = described_class.projected_transfer(50.0, catalog_entry: catalog)

    expect(amount).to eq(2_500.0)
  end

  it "projects transfer on MS 0–10 scale for linkage aggregate indicators" do
    catalog = IndicatorCatalog.new(code: "CVAT", funding_component: "linkage", team_kind: "esf")
    amount = described_class.projected_transfer(8.0, catalog_entry: catalog, score_scale: "ms_0_10")

    expect(amount).to eq(4_000.0)
  end

  it "projects stub transfer on MS 0–10 scale without catalog entry" do
    amount = described_class.projected_transfer_stub(8.0, score_scale: "ms_0_10")

    expect(amount).to eq(9_600.0)
  end

  it "caps linkage tier when cadastro exceeds team limit" do
    citizens = double(count: 4_000)
    rules = [
      instance_double(
        IndicatorRule,
        expression: {
          "caps_linkage_tier" => "good",
          "numerator" => { "team_limit" => 3_500 }
        }
      )
    ]

    tier = described_class.apply_linkage_tier_cap("excellent", rules: rules, citizens: citizens)

    expect(tier).to eq("good")
  end

  it "caps CVAT tier using V_CAD lim_cad rule when cadastro exceeds team limit" do
    cap_rule = instance_double(
      IndicatorRule,
      expression: {
        "caps_linkage_tier" => "good",
        "numerator" => { "team_limit" => 3_500 }
      }
    )
    citizens = double(count: 4_000)
    care_team = instance_double(CareTeam, team_kind: "esf")

    allow(described_class).to receive(:linkage_cap_rule_for).with(care_team).and_return(cap_rule)

    tier = described_class.apply_linkage_tier_cap_for_indicator(
      "excellent",
      indicator_code: "CVAT",
      care_team: care_team,
      citizens: citizens,
      rules: []
    )

    expect(tier).to eq("good")
  end
end
