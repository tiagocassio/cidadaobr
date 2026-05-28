# frozen_string_literal: true

module Ledi
  module PayloadExtractors
    module_function

    def record_uuid(payload, record_type:)
      case record_type
      when "FCC"
        payload["uuid_evolucao"] || payload["uuidEvolucao"]
      else
        payload["uuid"] || payload["uuid_ficha"] || payload["uuidFicha"]
      end
    end

    def originator_record_uuid(payload, record_type:)
      case record_type
      when "FCI", "FCD"
        payload["uuid_ficha_originadora"] || payload["uuidFichaOriginadora"]
      when "FCC"
        payload["uuid_cuidado_compartilhado"] || payload["uuidCuidadoCompartilhado"]
      end
    end

    def encounter_at(payload)
      timestamp = payload["header_transport"]&.dig("data_atendimento") ||
        payload["headerTransport"]&.dig("dataAtendimento") ||
        payload["data_atendimento"] ||
        payload["dataAtendimento"]

      return if timestamp.blank?

      Time.zone.at(timestamp.to_i / 1000)
    end

    def professional_cns(payload)
      payload.dig("header_transport", "cns") ||
        payload.dig("headerTransport", "cns")
    end

    def citizen_identifiers(payload)
      identification = payload["identificacao_usuario_cidadao"] || payload["identificacaoUsuarioCidadao"] || payload
      {
        cpf: identification["cpf_cidadao"] || identification["cpfCidadao"],
        cns: identification["cns_cidadao"] || identification["cns"] || identification["cnsCidadao"]
      }
    end
  end
end
