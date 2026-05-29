# frozen_string_literal: true

require "rails_helper"

RSpec.describe CitizenIndicatorGap do
  let(:municipality) { create(:municipality) }
  let(:facility) { create(:health_facility, municipality: municipality) }
  let(:team) { create(:care_team, municipality: municipality, health_facility: facility) }
  let(:citizen) { create(:citizen, municipality: municipality, health_facility: facility, care_team: team) }

  before { load Rails.root.join("db/seeds/indicator_catalog.rb") }

  it "accepts official Portaria good practice codes" do
    gap = described_class.new(
      municipality: municipality,
      citizen: citizen,
      care_team: team,
      indicator_code: "V_CAD",
      good_practice_code: "V_CAD_COM",
      status: "open",
      due_on: Date.current
    )

    expect(gap).to be_valid
  end

  it "accepts linkage placeholder good practice codes without dsl_v1 rules" do
    gap = described_class.new(
      municipality: municipality,
      citizen: citizen,
      care_team: team,
      indicator_code: "V_CAD",
      good_practice_code: "V_CAD_ATU",
      status: "open",
      due_on: Date.current
    )

    expect(gap).to be_valid
  end

  it "rejects Portuguese abbreviations as good practice codes" do
    gap = described_class.new(
      municipality: municipality,
      citizen: citizen,
      care_team: team,
      indicator_code: "V_CAD",
      good_practice_code: "CAD",
      status: "open",
      due_on: Date.current
    )

    expect(gap).not_to be_valid
    expect(gap.errors[:good_practice_code]).to be_present
  end
end
