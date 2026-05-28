# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ledi::SerializedType do
  it "resolves all 13 configured record types" do
    expect(described_class.all.map(&:record_type)).to match_array(
      %w[FCI FCD FAI FAO FAC FP FV FVD FAD FAE FCZM FCC MCA]
    )
  end

  it "finds FCI by serialized type code 2" do
    entry = described_class.find!(2)
    expect(entry.record_type).to eq("FCI")
    expect(entry.archetype).to eq("monolithic")
  end
end
