# frozen_string_literal: true

require "rails_helper"

RSpec.describe Cidadaobr::Cpf do
  it "validates known valid CPF" do
    expect(described_class.valid?("39053344705")).to be(true)
  end

  it "rejects invalid checksum" do
    expect(described_class.valid?("39053344701")).to be(false)
  end

  it "generates valid CPF from stem" do
    cpf = described_class.generate(123_456_789)
    expect(described_class.valid?(cpf)).to be(true)
  end
end
