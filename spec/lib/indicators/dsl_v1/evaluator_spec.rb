# frozen_string_literal: true

require "rails_helper"

RSpec.describe Indicators::DslV1::Evaluator do
  let(:municipality) { create(:municipality) }
  let(:facility) { create(:health_facility, municipality: municipality) }
  let(:team) { create(:care_team, municipality: municipality, health_facility: facility) }
  let(:membership) { create(:user_municipality_membership, municipality: municipality, scope: "municipality") }

  before { load Rails.root.join("db/seeds/indicator_catalog.rb") }

  def expression_for(code)
    IndicatorCatalog.find_by!(code: code).indicator_rules.first.expression
  end

  it "detects incomplete registration for V_CAD" do
    citizen = with_tenant(membership) do
      create(:citizen, municipality: municipality, health_facility: facility, care_team: team, birth_date: nil)
    end

    result = described_class.evaluate(
      expression: expression_for("V_CAD"),
      context: Indicators::DslV1::Context.new(citizen: citizen)
    )

    expect(result.in_denominator).to be(true)
    expect(result.meets_numerator).to be(false)
  end

  it "resolves complete registration for V_CAD" do
    citizen = with_tenant(membership) do
      create(
        :citizen,
        municipality: municipality,
        health_facility: facility,
        care_team: team,
        birth_date: Date.new(1980, 1, 1),
        full_name: "Maria Test"
      )
    end

    result = described_class.evaluate(
      expression: expression_for("V_CAD"),
      context: Indicators::DslV1::Context.new(citizen: citizen)
    )

    expect(result.meets_numerator).to be(true)
  end

  it "computes team score from citizens in denominator" do
    citizens = with_tenant(membership) do
      [
        create(:citizen, municipality: municipality, health_facility: facility, care_team: team, birth_date: Date.new(1980, 1, 1), full_name: "A"),
        create(:citizen, municipality: municipality, health_facility: facility, care_team: team, birth_date: nil, full_name: "B")
      ]
    end

    score = with_tenant(membership) do
      described_class.team_score(
        expression: expression_for("V_CAD"),
        citizens: Citizen.where(id: citizens.map(&:id)),
        quadrimester: "2026-Q1"
      )
    end

    expect(score).to eq(50.0)
  end
end
