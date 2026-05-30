# frozen_string_literal: true

module Indicators
  module DslV1
    module Resolvers
      module RegistrationValidators
        module_function

        def mici_complete?(citizen)
          payload = CitizenScope.latest_fci_payload(citizen)
          return false if payload.blank?

          ident = find_section(payload, %w[identificacaoUsuarioCidadao identificacao_usuario_cidadao dadosIdentificacao])
          name_present = dig_any(ident, %w[nome nomeSocial nome_social nomeCidadao]) || citizen.full_name.present?
          birth_present = dig_any(ident, %w[dataNascimento data_nascimento]) || citizen.birth_date.present?
          doc_present = dig_any(ident, %w[cpfCidadao cpf_cidadao cns cnsCidadao cns_cidadao]) || citizen.cpf.present?

          name_present && birth_present && doc_present && citizen.care_team_id.present?
        end

        def micdt_complete?(citizen)
          fcd = latest_fcd_payload(citizen)
          return false if fcd.blank?

          micro = dig_any(fcd, %w[microArea micro_area codigoMicroArea codigo_micro_area])
          address = find_section(fcd, %w[enderecoLocalPermanencia endereco_local_permanencia endereco])
          address_present = address.is_a?(Hash) && (
            dig_any(address, %w[nuCep cep logradouro bairro]).present?
          )

          micro.present? && address_present
        end

        def fci_updated_at(citizen)
          payload = CitizenScope.latest_fci_payload(citizen)
          return nil if payload.blank?

          raw = dig_any(payload, %w[dataAtualizacao data_atualizacao dtAtualizacao dt_atualizacao])
          parse_time(raw)
        end

        def team_citizen_count(citizen, cache)
          team_id = citizen.care_team_id
          return 0 if team_id.blank?

          cache_key = [ :team_citizen_count, citizen.municipality_id, team_id ]
          cache[cache_key] ||= Citizen.where(municipality_id: citizen.municipality_id, care_team_id: team_id).count
        end

        def latest_fcd_payload(citizen)
          ClinicalRecord
            .joins(:encounters)
            .where(municipality_id: citizen.municipality_id, record_type: "FCD", validation_status: "valid")
            .where(encounters: { citizen_id: citizen.id })
            .order(updated_at: :desc)
            .first
            &.payload_json
        end

        def dig_any(hash, keys)
          return nil unless hash.is_a?(Hash)

          keys.each do |key|
            val = hash[key] || hash[key.camelize(:lower)] || hash[key.camelize]
            return val if val.present?
          end
          nil
        end

        def find_section(payload, keys)
          keys.each do |key|
            section = payload[key] || payload[key.camelize(:lower)]
            return section if section.present?
          end
          nil
        end

        def parse_time(value)
          return value if value.is_a?(Time) || value.is_a?(ActiveSupport::TimeWithZone)
          return value.to_time if value.is_a?(Date)

          Time.zone.parse(value.to_s)
        rescue ArgumentError, TypeError
          nil
        end
      end
    end
  end
end
