# frozen_string_literal: true

module Ledi
  module Projectors
    class HouseholdProjector
      def self.call(clinical_record:)
        return unless clinical_record.record_type == "FCD"

        payload = clinical_record.payload_json
        address = payload["endereco_local_permanencia"] || payload["enderecoLocalPermanencia"] || {}

        household = Household.find_or_initialize_by(
          municipality_id: clinical_record.municipality_id,
          clinical_record_id: clinical_record.id
        )
        location = Cidadaobr::GeoPoint.from_clinical_record_payload(payload)
        micro_area = payload["micro_area"] || payload["microArea"] || address["micro_area"] || address["microArea"]
        housing_conditions = extract_housing_conditions(payload)

        household.assign_attributes(
          health_facility_id: clinical_record.health_facility_id,
          care_team_id: clinical_record.care_team_id,
          ibge_code: clinical_record.ibge_code,
          micro_area_code: micro_area&.to_s,
          street: dig(address, "nome_logradouro", "nomeLogradouro"),
          street_number: dig(address, "numero", "numero"),
          complement: dig(address, "complemento", "complemento"),
          neighborhood: dig(address, "bairro", "bairro"),
          postal_code: dig(address, "cep", "nuCep", "nu_cep"),
          reference_point: dig(address, "ponto_referencia", "pontoReferencia"),
          contact_phone: dig(address, "telefone_contato", "telefoneContato"),
          residence_phone: dig(address, "telefone_residencia", "telefoneResidencia"),
          no_street_number: truthy?(dig(address, "st_sem_numero", "stSemNumero")) || false,
          outside_micro_area: truthy?(dig(address, "st_fora_area", "stForaArea")) || false,
          property_type: payload["tipo_de_imovel"] || payload["tipoDeImovel"],
          housing_conditions: housing_conditions,
          animals_on_premises: truthy?(payload["st_animais_no_domicilio"] || payload["stAnimaisNoDomicilio"]) || false,
          location: location
        )
        household.save!

        sync_animals!(household, payload)
        sync_families!(household, clinical_record, payload)

        household
      end

      def self.extract_housing_conditions(payload)
        raw = payload["condicao_moradia"] || payload["condicaoMoradia"] || {}
        return {} unless raw.is_a?(Hash)

        keys = Household::HOUSING_CONDITION_KEYS + Household::HOUSING_CONDITION_STRING_KEYS
        keys.index_with do |key|
          camel = key.camelize(:lower)
          val = raw[key] || raw[camel]
          next if val.blank?

          Household::HOUSING_CONDITION_STRING_KEYS.include?(key) ? val.to_s : val.to_i
        end.compact
      end

      def self.sync_animals!(household, payload)
        return unless truthy?(payload["st_animais_no_domicilio"] || payload["stAnimaisNoDomicilio"])

        types = Array(payload["animais_no_domicilio"] || payload["animaisNoDomicilio"])
        return if types.empty?

        quantity = payload["quantos_animais_no_domicilio"] || payload["quantosAnimaisNoDomicilio"]
        per_species = quantity.present? ? [ quantity.to_i, 1 ].max : 1

        types.each do |species_code|
          label = "espécie #{species_code}"
          household.household_animals.find_or_create_by!(species: label) do |animal|
            animal.quantity = per_species
          end
        end
      end

      def self.sync_families!(household, clinical_record, payload)
        Array(payload["familias"]).each do |family|
          cpf = family["cpf_responsavel"] || family["cpfResponsavel"] || family["cpf_responsavel_familiar"]
          cns = family["numero_cns_responsavel"] || family["numeroCnsResponsavel"] || family["cns_responsavel_familiar"]
          next if cpf.blank? && cns.blank?

          citizen = find_or_create_citizen!(clinical_record, cpf: cpf, cns: cns)
          HouseholdMember.find_or_create_by!(household: household, citizen: citizen) do |member|
            member.family_reference = true
          end
        end
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

      def self.dig(hash, *keys)
        keys.each do |key|
          val = hash[key] || hash[key.to_s]
          return val if val.present?
        end
        nil
      end

      def self.truthy?(value)
        ActiveModel::Type::Boolean.new.cast(value)
      end
    end
  end
end
