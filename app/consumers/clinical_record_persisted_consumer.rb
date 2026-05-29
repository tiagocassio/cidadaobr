# frozen_string_literal: true

class ClinicalRecordPersistedConsumer < ApplicationConsumer
  PROJECTION_RETRY_GRACE = 2.minutes

  def consume
    messages.each do |message|
      envelope = nil
      process_with_idempotency(message) do |payload|
        envelope = payload
        project_clinical_record!(payload)
        # Inline recalc keeps indicator dashboard current without a separate Kafka hop.
        recalculate_indicators!(payload)
      end
    rescue Ledi::Errors::MissingClinicalRecordError => e
      if projection_stale?(envelope, message: message)
        Rails.logger.error("[Kafka] dropping stale clinical.record.persisted: #{e.message}")
        mark_as_consumed(message)
      else
        raise
      end
    end
  end

  private

  def project_clinical_record!(payload)
    clinical_record_id = payload.dig("payload", "clinical_record_id") || payload["clinical_record_id"]
    clinical_record = ClinicalRecord.find_by(id: clinical_record_id)

    unless clinical_record
      Rails.logger.warn(
        "[Kafka] clinical.record.persisted missing clinical_record_id=#{clinical_record_id.inspect}"
      )
      raise Ledi::Errors::MissingClinicalRecordError,
            "Clinical record #{clinical_record_id.inspect} not found for projection"
    end

    Ledi::ProjectionRunner.call(clinical_record: clinical_record)
  end

  def recalculate_indicators!(payload)
    clinical_record_id = payload.dig("payload", "clinical_record_id") || payload["clinical_record_id"]
    clinical_record = ClinicalRecord.find_by(id: clinical_record_id)
    return unless clinical_record

    Indicators::RecalculateForClinicalRecord.call(clinical_record: clinical_record)
  end

  def projection_stale?(payload, message: nil)
    reference_time = event_time_from(payload) || kafka_message_time(message)
    return false unless reference_time

    reference_time <= PROJECTION_RETRY_GRACE.ago
  end

  def event_time_from(payload)
    return if payload.blank?

    value = payload["occurred_at"]
    return if value.blank?

    Time.zone.parse(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end

  def kafka_message_time(message)
    return unless message.respond_to?(:metadata)

    timestamp = message.metadata&.timestamp
    return unless timestamp

    timestamp.is_a?(Time) ? timestamp.in_time_zone : Time.zone.at(timestamp)
  rescue ArgumentError, TypeError
    nil
  end
end
