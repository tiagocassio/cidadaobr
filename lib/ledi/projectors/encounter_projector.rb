# frozen_string_literal: true

module Ledi
  module Projectors
    class EncounterProjector
      ENCOUNTER_RECORD_TYPES = %w[FAI FAO FP FV FVD FAD].freeze

      def self.call(clinical_record:)
        return unless ENCOUNTER_RECORD_TYPES.include?(clinical_record.record_type)

        if clinical_record.clinical_record_items.exists?
          clinical_record.clinical_record_items.find_each do |item|
            project_item_encounter!(clinical_record, item)
          end
        else
          project_record_encounter!(clinical_record)
        end
      end

      def self.project_item_encounter!(clinical_record, item)
        citizen = resolve_citizen(clinical_record, item.payload_json)
        Encounter.find_or_create_by!(
          municipality_id: clinical_record.municipality_id,
          clinical_record_id: clinical_record.id,
          clinical_record_item_id: item.id
        ) do |encounter|
          encounter.health_facility_id = clinical_record.health_facility_id
          encounter.care_team_id = clinical_record.care_team_id
          encounter.citizen_id = citizen&.id
          encounter.record_type = clinical_record.record_type
          encounter.encounter_at = item_encounter_at(item.payload_json) || clinical_record.encounter_at || Time.current
        end
      end

      def self.project_record_encounter!(clinical_record)
        citizen = resolve_citizen(clinical_record, clinical_record.payload_json)
        Encounter.find_or_create_by!(
          municipality_id: clinical_record.municipality_id,
          clinical_record_id: clinical_record.id,
          clinical_record_item_id: nil
        ) do |encounter|
          encounter.health_facility_id = clinical_record.health_facility_id
          encounter.care_team_id = clinical_record.care_team_id
          encounter.citizen_id = citizen&.id
          encounter.record_type = clinical_record.record_type
          encounter.encounter_at = clinical_record.encounter_at || Time.current
        end
      end

      def self.resolve_citizen(clinical_record, payload)
        identifiers = PayloadExtractors.citizen_identifiers(payload)
        if identifiers[:cpf].present?
          Citizen.find_by(municipality_id: clinical_record.municipality_id, cpf: identifiers[:cpf])
        elsif identifiers[:cns].present?
          Citizen.find_by(municipality_id: clinical_record.municipality_id, cns: identifiers[:cns])
        end
      end

      def self.item_encounter_at(payload)
        timestamp = payload["data_hora_inicial_atendimento"] || payload["dataHoraInicialAtendimento"]
        return if timestamp.blank?

        Time.zone.at(timestamp.to_i / 1000)
      end
    end
  end
end
