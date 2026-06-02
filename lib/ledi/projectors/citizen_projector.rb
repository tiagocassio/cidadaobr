# frozen_string_literal: true

module Ledi
  module Projectors
    class CitizenProjector
      def self.call(clinical_record:)
        return unless clinical_record.record_type == "FCI"

        payload = clinical_record.payload_json
        identification = payload["identificacao_usuario_cidadao"] || {}
        cpf = identification["cpf_cidadao"]
        cns = identification["cns_cidadao"] || identification["cns"]
        return if cpf.blank? && cns.blank?

        citizen = if cpf.present?
          Citizen.find_or_initialize_by(municipality_id: clinical_record.municipality_id, cpf: cpf)
        else
          Citizen.find_or_initialize_by(municipality_id: clinical_record.municipality_id, cns: cns)
        end

        was_new = citizen.new_record?
        citizen.assign_attributes(
          health_facility_id: clinical_record.health_facility_id,
          care_team_id: clinical_record.care_team_id,
          clinical_record: clinical_record,
          cpf: cpf,
          cns: cns,
          full_name: identification["nome_cidadao"] || identification["nome_social"],
          birth_date: epoch_to_date(identification["data_nascimento_cidadao"]),
          sex: identification["sexo_cidadao"]&.to_s
        )
        citizen.save!

        if was_new
          RecordPlatformEvent.call(
            event_type: Cidadaobr::KafkaTopics::CITIZEN_REGISTERED,
            aggregate_type: "Citizen",
            aggregate_id: citizen.id,
            payload: { citizen_id: citizen.id, clinical_record_id: clinical_record.id },
          care_team_id: clinical_record.care_team_id
          )
        end

        citizen
      end

      def self.epoch_to_date(value)
        return if value.blank?

        Time.zone.at(value.to_i / 1000).to_date
      end
    end
  end
end
