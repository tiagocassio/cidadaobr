# frozen_string_literal: true

module Ledi
  module Projectors
    class HouseholdProjector
      def self.call(clinical_record:)
        return unless clinical_record.record_type == "FCD"

        payload = clinical_record.payload_json
        address = payload["endereco_local_permanencia"] || {}

        household = Household.find_or_initialize_by(
          municipality_id: clinical_record.municipality_id,
          clinical_record_id: clinical_record.id
        )
        location = Cidadaobr::GeoPoint.from_clinical_record_payload(payload)

        household.assign_attributes(
          health_facility_id: clinical_record.health_facility_id,
          care_team_id: clinical_record.care_team_id,
          ibge_code: clinical_record.ibge_code,
          micro_area_code: payload["micro_area"]&.to_s,
          street: address["nome_logradouro"],
          street_number: address["numero"],
          complement: address["complemento"],
          neighborhood: address["bairro"],
          postal_code: address["cep"],
          location: location
        )
        household.save!

        Array(payload["familias"]).each do |family|
          cpf = family["cpf_responsavel"] || family["cpf_responsavel_familiar"]
          cns = family["numero_cns_responsavel"] || family["cns_responsavel_familiar"]
          next if cpf.blank? && cns.blank?

          citizen = find_or_create_citizen!(clinical_record, cpf: cpf, cns: cns)
          HouseholdMember.find_or_create_by!(household: household, citizen: citizen) do |member|
            member.family_reference = true
          end
        end

        household
      end

      def self.find_or_create_citizen!(clinical_record, cpf:, cns:)
        citizen = Citizen.find_by(municipality_id: clinical_record.municipality_id, cpf: cpf) if cpf.present?
        citizen ||= Citizen.find_by(municipality_id: clinical_record.municipality_id, cns: cns) if cns.present?
        citizen || Citizen.create!(
          municipality_id: clinical_record.municipality_id,
          health_facility_id: clinical_record.health_facility_id,
          care_team_id: clinical_record.care_team_id,
          cpf: cpf,
          cns: cns
        )
      end
    end
  end
end
