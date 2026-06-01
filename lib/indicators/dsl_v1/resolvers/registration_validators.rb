# frozen_string_literal: true

module Indicators
  module DslV1
    module Resolvers
      module RegistrationValidators
        module_function

        # ADR-0005: MICI requires valid FCI identificacao fields — no fallback to municipal citizen columns.
        def mici_complete?(citizen)
          payload = CitizenScope.latest_fci_payload(citizen)
          return false if payload.blank?

          ident = find_section(payload, %w[identificacaoUsuarioCidadao identificacao_usuario_cidadao dadosIdentificacao])
          return false unless ident.is_a?(Hash)

          name_present = dig_any(ident, %w[nome nomeSocial nome_social nomeCidadao]).present?
          birth_present = dig_any(ident, %w[dataNascimento data_nascimento]).present?
          doc_present = dig_any(ident, %w[cpfCidadao cpf_cidadao cns cnsCidadao cns_cidadao]).present?

          name_present && birth_present && doc_present && citizen.care_team_id.present?
        end

        def micdt_complete?(citizen)
          fcd = latest_fcd_payload(citizen)
          return false if fcd.blank?

          micro = fcd_micro_area_code(fcd)
          address = find_section(fcd, %w[enderecoLocalPermanencia endereco_local_permanencia endereco])
          address_present = address.is_a?(Hash) && (
            dig_any(address, %w[nuCep cep logradouro nome_logradouro nomeLogradouro bairro]).present?
          )

          micro.present? && address_present
        end

        # NT 30/2025 transversal: adscrição FCI/FCD microárea (sem exigir MICI/MICDT completos).
        def microarea_linked?(citizen)
          fci = CitizenScope.latest_fci_payload(citizen)
          return false if fci.blank?

          fci_micro = fci_micro_area_code(fci)
          return false if fci_micro.blank?

          fcd_micro = fcd_micro_area_code(latest_fcd_payload(citizen))
          fcd_micro = citizen.household_members.order(:created_at).first&.household&.micro_area_code if fcd_micro.blank?
          return false if fcd_micro.blank?

          normalize_micro_area(fci_micro) == normalize_micro_area(fcd_micro)
        end

        def fci_flag_present?(citizen, flag)
          payload = CitizenScope.latest_fci_payload(citizen)
          return false if payload.blank?

          CitizenScope.condition_truthy?(payload, flag.to_s)
        end

        def fci_micro_area_code(payload)
          ident = find_section(payload, %w[identificacaoUsuarioCidadao identificacao_usuario_cidadao dadosIdentificacao])
          ident_micro = ident.is_a?(Hash) ? dig_any(ident, %w[microArea micro_area codigoMicroArea codigo_micro_area]) : nil
          ident_micro.presence || dig_any(payload, %w[microArea micro_area codigoMicroArea codigo_micro_area])
        end

        def fcd_micro_area_code(payload)
          return nil if payload.blank?

          root = dig_any(payload, %w[microArea micro_area codigoMicroArea codigo_micro_area])
          return root if root.present?

          address = find_section(payload, %w[enderecoLocalPermanencia endereco_local_permanencia endereco])
          return nil unless address.is_a?(Hash)

          dig_any(address, %w[microArea micro_area codigoMicroArea codigo_micro_area])
        end

        def normalize_micro_area(value)
          value.to_s.strip.sub(/\A0+/, "").presence || value.to_s.strip
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
          record = ClinicalRecord
            .joins(:encounters)
            .where(municipality_id: citizen.municipality_id, record_type: "FCD", validation_status: "valid")
            .where(encounters: { citizen_id: citizen.id })
            .order(updated_at: :desc)
            .first
          return record.payload_json if record

          household = citizen.household_members.order(:created_at).first&.household
          household&.to_fcd_payload
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
