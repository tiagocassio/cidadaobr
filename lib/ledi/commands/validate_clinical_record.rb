# frozen_string_literal: true

module Ledi
  class ValidateClinicalRecord < ApplicationCommand
    def initialize(clinical_record_id:)
      @clinical_record_id = clinical_record_id
    end

    def call
      clinical_record = ClinicalRecord.find_by!(id: @clinical_record_id)
      result = ValidationEngine.call(clinical_record: clinical_record)

      write_transaction do
        if result.valid
          clinical_record.update!(validation_status: "valid", validation_errors: [])
          clinical_record.transport_record.update!(status: "validated")

          RecordPlatformEvent.call(
            event_type: Cidadaobr::KafkaTopics::CLINICAL_RECORD_VALIDATED,
            aggregate_type: "ClinicalRecord",
            aggregate_id: clinical_record.id,
            payload: event_payload(clinical_record),
            care_team_id: clinical_record.care_team_id
          )

          RecordPlatformEvent.call(
            event_type: Cidadaobr::KafkaTopics::CLINICAL_RECORD_PERSISTED,
            aggregate_type: "ClinicalRecord",
            aggregate_id: clinical_record.id,
            payload: event_payload(clinical_record),
            care_team_id: clinical_record.care_team_id
          )
        else
          clinical_record.update!(validation_status: "invalid", validation_errors: result.errors)
          clinical_record.transport_record.update!(status: "draft")

          RecordPlatformEvent.call(
            event_type: Cidadaobr::KafkaTopics::CLINICAL_RECORD_VALIDATION_FAILED,
            aggregate_type: "ClinicalRecord",
            aggregate_id: clinical_record.id,
            payload: event_payload(clinical_record).merge(errors: result.errors),
            care_team_id: clinical_record.care_team_id
          )
        end

        result
      end
    end

    private

    def event_payload(clinical_record)
      {
        clinical_record_id: clinical_record.id,
        transport_record_id: clinical_record.transport_record_id,
        record_type: clinical_record.record_type,
        record_uuid: clinical_record.record_uuid
      }
    end
  end
end
