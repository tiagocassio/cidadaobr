# frozen_string_literal: true

require "rails_helper"

RSpec.describe IndicatorCatalog do
  subject(:catalog) do
    described_class.new(
      code: "C1",
      name: "Mais acesso à APS",
      funding_component: "quality",
      methodology_version: "3493/2024",
      periodicity: "quarterly",
      team_kind: "esf",
      display_order: 10,
      active: true
    )
  end

  it "accepts Portaria 3.493/2024 codes" do
    expect(catalog).to be_valid
  end

  it "rejects codes outside Portaria 3.493/2024" do
    catalog.code = "C8"

    expect(catalog).not_to be_valid
    expect(catalog.errors[:code]).to be_present
  end

  it "delegates indicator codes to Indicators::Portaria3493" do
    expect(described_class::PORTARIA_3493_CODES).to eq(Indicators::Portaria3493::INDICATOR_CODES)
  end

  it "defines the same codes in locale catalog names" do
    described_class::PORTARIA_3493_CODES.each do |code|
      key = "cidadaobr.indicators.catalog.#{code}.name"
      expect(I18n.exists?(key)).to be(true), "missing locale for #{code}"
    end
  end
end
