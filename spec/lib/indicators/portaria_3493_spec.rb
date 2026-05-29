# frozen_string_literal: true

require "rails_helper"

RSpec.describe Indicators::Portaria3493 do
  it "lists only official Portaria 3.493/2024 indicator codes" do
    expect(described_class::INDICATOR_CODES).to be_frozen
    expect(described_class::INDICATOR_CODES.size).to eq(19)
    expect(described_class::INDICATOR_CODES).not_to include("C8")
    expect(described_class::INDICATOR_CODES).to include("CVAT", "V_CAD", "C4", "B1", "M2")
  end

  it "rejects Portuguese abbreviations as good practice codes" do
    %w[CAD ACOMP SAT VAC].each do |legacy|
      expect(described_class.known_good_practice_code?(legacy)).to be(false)
    end
  end

  it "accepts official linkage rule codes from the plan" do
    expect(described_class.known_good_practice_code?("V_CAD_COM")).to be(true)
    expect(described_class.known_good_practice_code?("V_ACOMP_12M")).to be(true)
  end

  it "accepts linkage gap placeholders without dsl_v1 rules yet" do
    expect(described_class::LINKAGE_RULE_CODES).to include("V_CAD_ATU", "V_LIM_CAD")
    expect(described_class.known_good_practice_code?("V_CAD_ATU")).to be(true)
    expect(described_class.known_good_practice_code?("V_LIM_CAD")).to be(true)
  end
end
