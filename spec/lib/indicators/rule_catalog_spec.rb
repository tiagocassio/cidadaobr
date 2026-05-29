# frozen_string_literal: true

require "rails_helper"

RSpec.describe Indicators::RuleCatalog do
  before { load Rails.root.join("db/seeds/indicator_catalog.rb") }

  describe ".appointment_dependent_codes" do
    it "includes indicators whose dsl references appointments" do
      expect(described_class.appointment_dependent_codes).to include("C1")
    end
  end

  describe ".rule_applies_to_care_team?" do
    let(:team) { double(team_kind: nil) }
    let(:esf_rule) do
      instance_double(
        IndicatorRule,
        indicator_catalog: instance_double(IndicatorCatalog, team_kind: "esf")
      )
    end
    let(:esb_rule) do
      instance_double(
        IndicatorRule,
        indicator_catalog: instance_double(IndicatorCatalog, team_kind: "esb")
      )
    end

    it "applies esf catalog rules when care team has no team_kind (MVP)" do
      expect(described_class.rule_applies_to_care_team?(esf_rule, team)).to be(true)
    end

    it "skips esb catalog rules when care team has no team_kind" do
      expect(described_class.rule_applies_to_care_team?(esb_rule, team)).to be(false)
    end

    it "applies when care team team_kind matches catalog" do
      esb_team = double(team_kind: "esb")
      expect(described_class.rule_applies_to_care_team?(esb_rule, esb_team)).to be(true)
    end

    it "skips emulti catalog rules when care team has no team_kind" do
      emulti_rule = instance_double(
        IndicatorRule,
        indicator_catalog: instance_double(IndicatorCatalog, team_kind: "emulti")
      )

      expect(described_class.rule_applies_to_care_team?(emulti_rule, team)).to be(false)
    end
  end

  describe ".rules_for_care_team" do
    it "returns esf/municipality dsl_v1 rules when care team has no team_kind (MVP)" do
      team = double(team_kind: nil)
      codes = described_class.rules_for_care_team(team).map { |rule| rule.indicator_catalog.code }

      expect(codes).to include("C1", "V_CAD")
      expect(codes).not_to include("B1", "M1")
    end

    it "filters by catalog team_kind when care team exposes team_kind" do
      esb_team = double(team_kind: "esb")
      codes = described_class.rules_for_care_team(esb_team).map { |rule| rule.indicator_catalog.code }

      expect(codes).not_to include("C1", "V_CAD")
    end
  end

  describe ".evaluable_indicator_codes" do
    it "returns only codes with dsl_v1 rules" do
      expect(described_class.evaluable_indicator_codes(%w[B1 C1 M2])).to match_array(%w[C1])
    end

    it "returns empty when every candidate is dsl_v1_stub" do
      expect(described_class.evaluable_indicator_codes(%w[B1 B2 M1 M2])).to eq([])
    end
  end

  describe ".references_appointments?" do
    it "detects appointment numerator clauses" do
      clause = { "type" => "appointment_in_quadrimester", "statuses" => %w[scheduled] }

      expect(described_class.references_appointments?(clause)).to be(true)
    end

    it "detects nested appointment clauses" do
      clause = {
        "all" => [
          { "type" => "encounter_in_window", "within_months" => 12 },
          { "type" => "appointment_in_quadrimester", "statuses" => %w[scheduled] }
        ]
      }

      expect(described_class.references_appointments?(clause)).to be(true)
    end
  end
end
