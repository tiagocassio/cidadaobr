# frozen_string_literal: true

module Ledi
  module Projectors
    class CitizenImmunizationProjector
      def self.call(clinical_record:)
        new(clinical_record: clinical_record).call
      end

      def initialize(clinical_record:)
        @clinical_record = clinical_record
      end

      def call
        citizen = find_citizen
        return unless citizen

        vaccine_rows.each { |row| upsert_immunization!(citizen: citizen, row: row) }
      end

      private

      def find_citizen
        Citizen.find_by(clinical_record_id: @clinical_record.id) ||
          Citizen.find_by(municipality_id: @clinical_record.municipality_id, cpf: payload_cpf)
      end

      def upsert_immunization!(citizen:, row:)
        code = vaccine_code_for(row)
        dose = dose_label_for(row)
        return if code.blank?

        record = CitizenImmunizationRecord.find_or_initialize_by(
          municipality_id: @clinical_record.municipality_id,
          citizen_id: citizen.id,
          vaccine_code: code,
          dose_label: dose
        )
        record.assign_attributes(
          vaccine_name: vaccine_name_for(row, code),
          applied_on: applied_on_for(row),
          lot_number: lot_number_for(row)
        )
        record.source = "fv_projection" if record.new_record?
        record.save!
      end

      def vaccine_rows
        rows = []
        rows.concat(Array(nested_vaccination_rows))
        rows << flat_vaccination_row if flat_vaccination_row.present?
        rows.compact
      end

      def nested_vaccination_rows
        Array(payload["vacinacoes"]).flat_map do |section|
          next [] unless section.is_a?(Hash)

          applied_on = parse_date(section["dataAtendimento"] || section["data_atendimento"]) ||
                       parse_date(@clinical_record.encounter_at)
          Array(section["vacinas"]).map do |vaccine_row|
            next unless vaccine_row.is_a?(Hash)

            vaccine_row.merge(
              "_applied_on" => applied_on,
              "_section" => section
            )
          end
        end.flatten.compact
      end

      def flat_vaccination_row
        return nil if payload.dig("vacina", "codigo").blank? && payload["vaccine_code"].blank?

        {
          "imunobiologico" => payload.dig("vacina", "codigo") || payload["vaccine_code"],
          "nomeImunobiologico" => payload.dig("vacina", "nome") || payload["vaccine_name"],
          "dose" => payload.dig("dose", "rotulo") || payload.dig("dose", "codigo") || payload["dose_label"],
          "lote" => payload.dig("lote", "numero") || payload["lot_number"],
          "_applied_on" => parse_date(payload["data_aplicacao"] || payload["applied_on"]) ||
                           parse_date(@clinical_record.encounter_at)
        }
      end

      def payload
        @payload ||= @clinical_record.payload_json.is_a?(Hash) ? @clinical_record.payload_json : {}
      end

      def payload_cpf
        nested = Array(payload["vacinacoes"]).find { |section| section.is_a?(Hash) }
        nested&.dig("cpfCidadao") ||
          nested&.dig("cpf_cidadao") ||
          payload.dig("identificacao", "cpf") ||
          payload["cpf"]
      end

      def vaccine_code_for(row)
        value = row["imunobiologico"] || row["codigoImunobiologico"] || row["codigo_imunobiologico"] ||
                row["codigoVacina"] || row["codigo_vacina"] || row["codigo"]
        normalize_code(value)
      end

      def vaccine_name_for(row, code)
        row["nomeImunobiologico"] || row["nome_imunobiologico"] || row["descricao"] || row["imunobiologico"] ||
          code.to_s
      end

      def dose_label_for(row)
        dose = row["dose"] || row["dose_label"]
        return dose["rotulo"] || dose["codigo"] || dose["codigo_dose"] if dose.is_a?(Hash)

        dose
      end

      def applied_on_for(row)
        row["_applied_on"] || parse_date(@clinical_record.encounter_at)
      end

      def lot_number_for(row)
        row["lote"] || row.dig("lote", "numero") || row["lot_number"]
      end

      def normalize_code(code)
        Indicators::PniCodeNormalizer.normalize_code(code)
      end

      def parse_date(value)
        return value if value.is_a?(Date)
        return value.to_date if value.respond_to?(:to_date) && !value.is_a?(String)

        Date.parse(value.to_s)
      rescue ArgumentError, TypeError
        nil
      end
    end
  end
end
