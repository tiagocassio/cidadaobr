# frozen_string_literal: true

module Ledi
  class ValidateClinicalRecord < ApplicationCommand
    def initialize(clinical_record_id:)
      @clinical_record_id = clinical_record_id
    end

    def call
      clinical_record = ClinicalRecord.find_by!(id: @clinical_record_id)
      result = ValidationEngine.call(clinical_record: clinical_record)

      ActiveRecord::Base.transaction do
        if result.valid
          clinical_record.update!(validation_status: "valid", validation_errors: [])
          clinical_record.transport_record.update!(status: "validated")

          RecordPlatformEvent.call(
            event_type: "clinical.record.validated",
            aggregate_type: "ClinicalRecord",
            aggregate_id: clinical_record.id,
            payload: event_payload(clinical_record),
            topic: OutboxPublisher::TOPIC_MAPPING.fetch("clinical.record.validated"),
            care_team_id: clinical_record.care_team_id
          )

          RecordPlatformEvent.call(
            event_type: "clinical.record.persisted",
            aggregate_type: "ClinicalRecord",
            aggregate_id: clinical_record.id,
            payload: event_payload(clinical_record),
            topic: OutboxPublisher::TOPIC_MAPPING.fetch("clinical.record.persisted"),
            care_team_id: clinical_record.care_team_id
          )
        else
          clinical_record.update!(validation_status: "invalid", validation_errors: result.errors)
          clinical_record.transport_record.update!(status: "draft")

          RecordPlatformEvent.call(
            event_type: "clinical.record.validation_failed",
            aggregate_type: "ClinicalRecord",
            aggregate_id: clinical_record.id,
            payload: event_payload(clinical_record).merge(errors: result.errors),
            topic: OutboxPublisher::TOPIC_MAPPING.fetch("clinical.record.validation_failed"),
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
