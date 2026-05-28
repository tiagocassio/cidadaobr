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
        citizen = Citizen.find_by(clinical_record_id: @clinical_record.id) ||
          Citizen.find_by(municipality_id: @clinical_record.municipality_id, cpf: payload_cpf)

        return unless citizen

        record = CitizenImmunizationRecord.find_or_initialize_by(
          municipality_id: @clinical_record.municipality_id,
          citizen_id: citizen.id,
          vaccine_code: vaccine_code,
          dose_label: dose_label
        )
        # FV re-import is the source of truth for dose metadata; manual rows with the same
        # vaccine_code/dose_label are refreshed on each projection.
        record.assign_attributes(
          vaccine_name: vaccine_name,
          applied_on: applied_on,
          lot_number: lot_number
        )
        record.source = "fv_projection" if record.new_record?
        record.save!
      end

      private

      def payload
        @payload ||= @clinical_record.payload_json.is_a?(Hash) ? @clinical_record.payload_json : {}
      end

      def payload_cpf
        payload.dig("identificacao", "cpf") || payload["cpf"]
      end

      def vaccine_code
        payload.dig("vacina", "codigo") || payload["vaccine_code"] || "UNKNOWN"
      end

      def vaccine_name
        payload.dig("vacina", "nome") || payload["vaccine_name"] || vaccine_code
      end

      def dose_label
        payload.dig("dose", "rotulo") || payload["dose_label"]
      end

      def applied_on
        value = payload.dig("data_aplicacao") || payload["applied_on"]
        value.present? ? Date.parse(value.to_s) : nil
      rescue ArgumentError, TypeError
        nil
      end

      def lot_number
        payload.dig("lote", "numero") || payload["lot_number"]
      end
    end
  end
end
