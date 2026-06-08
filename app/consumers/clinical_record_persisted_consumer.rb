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
        build_feature_snapshot!(payload, message: message)
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

  def build_feature_snapshot!(payload, message: nil)
    clinical_record_id = payload.dig("payload", "clinical_record_id") || payload["clinical_record_id"]
    return if clinical_record_id.blank?

    computed_at = event_time_from(payload) || kafka_message_time(message) || Time.current
    CommandBus.dispatch(
      Ai::Commands::BuildCitizenFeatureSnapshot,
      clinical_record_id: clinical_record_id,
      computed_at: computed_at
    )
  rescue ActiveRecord::StatementInvalid => e
    raise unless row_level_security_violation?(e)

    # v1: offset still marked processed — see ADR-0007 pipeline ops (monitor + manual backfill).
    ActiveSupport::Notifications.instrument(
      "kafka.feature_snapshot.rls_skipped",
      clinical_record_id: clinical_record_id,
      error_class: e.class.name,
      error_message: e.message
    )
  end

  def row_level_security_violation?(error)
    error.cause.is_a?(PG::InsufficientPrivilege) ||
      error.message.include?("row-level security policy")
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
