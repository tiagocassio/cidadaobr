# frozen_string_literal: true

require "rails_helper"

RSpec.describe Indicators::RecordTypeIndex do
  it "maps FAO to eSB and eMulti catalog indicators" do
    expect(described_class.indicator_codes_for("FAO")).to match_array(%w[B1 B2 B3 B4 B5 B6 M1])
  end

  it "maps FAC to collective and eMulti indicators" do
    expect(described_class.indicator_codes_for("FAC")).to match_array(%w[B4 M1 M2])
  end

  it "maps FV to C6 only (CVAT is derived, not FV-driven)" do
    expect(described_class.indicator_codes_for("FV")).to eq(%w[C6])
  end
end
