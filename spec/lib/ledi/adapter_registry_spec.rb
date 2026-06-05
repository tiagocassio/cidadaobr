# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ledi::AdapterRegistry do
  it "registers adapters for all 13 LEDI record types" do
    expect(Ledi::AdapterRegistry::ADAPTER_CLASSES.keys.sort).to eq(
      %w[FAC FAD FAE FAI FAO FCC FCD FCI FCZM FP FV FVD MCA].sort
    )
  end

  it "instantiates each adapter from SerializedType" do
    Ledi::AdapterRegistry::ADAPTER_CLASSES.each_key do |record_type|
      adapter = Ledi::AdapterRegistry.fetch(record_type)
      expect(adapter).to be_a(Ledi::Adapters::BaseAdapter)
    end
  end
end
