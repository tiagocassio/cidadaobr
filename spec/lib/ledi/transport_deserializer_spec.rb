# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ledi::TransportDeserializer do
  describe ".call" do
    it "deserializes an FCI transport payload" do
      binary = LediFixtures.fci_binary(cnes: "2000001", ibge: "3550308")
      result = described_class.call(binary)

      expect(result.record_type).to eq("FCI")
      expect(result.serialized_type).to eq(2)
      expect(result.header[:cnes_dado_serializado]).to eq("2000001")
      expect(result.payload["tp_cds_origem"]).to eq(3)
      expect(result.payload.dig("identificacao_usuario_cidadao", "nome_cidadao")).to eq("Maria da Silva")
    end

    it "deserializes an FAI master payload with nested attendances" do
      binary = LediFixtures.fai_binary
      result = described_class.call(binary)

      expect(result.record_type).to eq("FAI")
      expect(result.role).to eq("master")
      expect(result.payload["atendimentos_individuais"].size).to eq(1)
    end
  end
end
