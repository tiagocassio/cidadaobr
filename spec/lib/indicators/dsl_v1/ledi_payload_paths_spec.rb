# frozen_string_literal: true

require "rails_helper"

RSpec.describe Indicators::DslV1::LediPayloadPaths do
  describe ".payload_field" do
    it "maps English aliases to LEDI payload keys" do
      expect(described_class.payload_field("individual_attendances")).to eq("atendimentos_individuais")
      expect(described_class.payload_field("measurements")).to eq("medicoes")
    end

    it "passes through unknown keys unchanged" do
      expect(described_class.payload_field("custom_field")).to eq("custom_field")
    end
  end

  describe ".payload_field_aliases" do
    it "returns multiple LEDI keys for immunizations and child development" do
      expect(described_class.payload_field_aliases("immunizations")).to include("vacina", "vacinacoes")
      expect(described_class.payload_field_aliases("child_development")).to include("desenvolvimento_infantil")
    end
  end

  describe ".fci_condition_field_aliases" do
    it "returns LEDI aliases for known condition flags" do
      expect(described_class.fci_condition_field_aliases("hypertension")).to include("hipertensao")
    end
  end
end
