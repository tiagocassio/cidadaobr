# frozen_string_literal: true

require "rails_helper"

RSpec.describe Indicators::PniCodeNormalizer do
  describe ".normalize_code" do
    it "strips non-digits and leading zeros from numeric codes" do
      expect(described_class.normalize_code("015")).to eq("15")
      expect(described_class.normalize_code("09")).to eq("9")
    end

    it "falls back to stripped string when no digits are present" do
      expect(described_class.normalize_code("BCG")).to eq("BCG")
    end
  end

  describe ".normalize_dose_code" do
    it "normalizes dose labels and strips a leading D prefix" do
      expect(described_class.normalize_dose_code("d1")).to eq("1")
      expect(described_class.normalize_dose_code("R1")).to eq("R1")
    end
  end
end
