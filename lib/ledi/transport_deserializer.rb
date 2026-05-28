# frozen_string_literal: true

module Ledi
  class TransportDeserializer
    Result = Data.define(
      :transport,
      :serialized_type,
      :record_type,
      :archetype,
      :role,
      :payload,
      :header
    )

    class << self
      def call(payload_binary)
        transport = ThriftReader.read(payload_binary, Br::Gov::Saude::Esusab::Dadotransp::DadoTransporteThrift)
        type_entry = SerializedType.find!(transport.tipoDadoSerializado)
        adapter = AdapterRegistry.fetch(type_entry.record_type)
        deserialized = adapter.deserialize(transport.dadoSerializado)

        Result.new(
          transport: transport,
          serialized_type: type_entry.code,
          record_type: type_entry.record_type,
          archetype: type_entry.archetype,
          role: deserialized[:role],
          payload: deserialized[:payload],
          header: header_json(transport)
        )
      end

      private

      def header_json(transport)
        remetente = transport.remetente
        {
          uuid_dado_serializado: transport.uuidDadoSerializado,
          cnes_dado_serializado: transport.cnesDadoSerializado,
          cod_ibge: transport.codIbge,
          ine_dado_serializado: transport.ineDadoSerializado,
          num_lote: transport.numLote,
          versao: transport.versao && StructToJson.convert(transport.versao),
          remetente: remetente && StructToJson.convert(remetente)
        }.compact
      end
    end
  end
end
