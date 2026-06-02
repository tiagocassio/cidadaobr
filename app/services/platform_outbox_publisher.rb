# frozen_string_literal: true

class PlatformOutboxPublisher
  STALE_PUBLISHING_AFTER = PlatformOutboxMessage::STALE_PUBLISHING_AFTER
  FAILED_RETRY_AFTER = PlatformOutboxMessage::FAILED_RETRY_AFTER
  MAX_PUBLISH_ATTEMPTS = PlatformOutboxMessage::MAX_PUBLISH_ATTEMPTS
  DEFAULT_FAILED_RETRY_LIMIT = PlatformOutboxMessage::DEFAULT_FAILED_RETRY_LIMIT
  RECLAIMED_STALE_MESSAGE = OutboxPublisher::RECLAIMED_STALE_MESSAGE

  TOPIC_MAPPING = Cidadaobr::KafkaTopics::EVENT_TO_TOPIC

  def self.publish_pending!(limit: 100, failed_retry_limit: DEFAULT_FAILED_RETRY_LIMIT)
    remaining = limit
    failed_requeue_remaining = failed_retry_limit

    loop do
      break if remaining <= 0
      break unless platform_outbox_work_present?

      if failed_requeue_remaining.positive?
        requeued = requeue_retryable_failed!(limit: failed_requeue_remaining)
        failed_requeue_remaining -= requeued
      end
      reclaim_stale_publishing!

      message = claim_next_for_publish!
      break unless message

      remaining -= 1
      publish_with_rescue!(message)
    end
  end

  def self.platform_outbox_work_present?
    PlatformOutboxMessage.pending.exists? ||
      PlatformOutboxMessage.stale_publishing.exists? ||
      PlatformOutboxMessage.where(status: "publishing").where.not(kafka_sent_at: nil).exists? ||
      PlatformOutboxMessage.retryable_failed.exists?
  end
  private_class_method :platform_outbox_work_present?

  def self.reclaim_stale_publishing!(stale_after: STALE_PUBLISHING_AFTER)
    reclaimed = PlatformOutboxMessage.stale_publishing(stale_after: stale_after).update_all(
      [
        "status = ?, publishing_claimed_at = NULL, updated_at = ?, " \
        "last_error = CASE WHEN last_error IS NULL OR last_error = '' THEN ? " \
        "ELSE last_error || ' | ' || ? END",
        "pending",
        Time.current,
        RECLAIMED_STALE_MESSAGE,
        RECLAIMED_STALE_MESSAGE
      ]
    )

    return if reclaimed.zero?

    Rails.logger.warn("[PlatformOutboxPublisher] Reclaimed #{reclaimed} stale publishing message(s)")
  end

  def self.requeue_retryable_failed!(retry_after: FAILED_RETRY_AFTER, limit: DEFAULT_FAILED_RETRY_LIMIT)
    ids = PlatformOutboxMessage.retryable_failed(retry_after: retry_after).order(:updated_at).limit(limit).pluck(:id)
    requeue_message_ids!(ids)
  end

  def self.requeue_message_ids!(ids, reset_attempts: false)
    return 0 if ids.empty?

    timestamp = Time.current
    shared_attrs = {
      status: "pending",
      last_error: nil,
      publishing_claimed_at: nil,
      permanent_failure: false,
      updated_at: timestamp
    }
    shared_attrs[:publish_attempts] = 0 if reset_attempts

    PlatformOutboxMessage.where(id: ids).update_all(shared_attrs)
  end

  def self.claim_next_for_publish!
    ActiveRecord::Base.transaction do
      message = PlatformOutboxMessage.pending.order(:created_at).limit(1).lock("FOR UPDATE SKIP LOCKED").first
      if message
        message.update!(status: "publishing", publishing_claimed_at: Time.current)
        return message
      end

      message = PlatformOutboxMessage.where(status: "publishing")
        .where.not(kafka_sent_at: nil)
        .order(:kafka_sent_at)
        .limit(1)
        .lock("FOR UPDATE SKIP LOCKED")
        .first
      message&.update_columns(publishing_claimed_at: Time.current)
      message
    end
  end

  def self.publish!(message)
    message.reload
    return if message.status == "published"

    refresh_publishing_claim!(message) if message.status == "publishing"

    event_id = extract_event_id!(message)
    return if event_id.nil?

    unless event_id.to_s == message.platform_event_id.to_s
      mark_permanent_failed!(message, "Outbox payload event_id must match platform_event_id")
      raise ArgumentError, "Outbox payload event_id must match platform_event_id"
    end

    if message.kafka_sent_at.present?
      mark_published!(message)
      return
    end

    begin
      Karafka.producer.produce_sync(
        topic: message.topic,
        payload: message.payload.to_json,
        key: event_id.to_s
      )
    rescue StandardError => e
      mark_failed!(message, e.message)
      raise
    end

    record_kafka_publish!(message)
  end

  def self.extract_event_id!(message)
    event_id = message.payload.with_indifferent_access[:event_id]
    if event_id.blank?
      mark_permanent_failed!(message, "Outbox payload missing event_id")
      return nil
    end

    event_id
  end
  private_class_method :extract_event_id!

  def self.mark_published!(message)
    message.update!(
      status: "published",
      published_at: Time.current,
      last_error: nil,
      publishing_claimed_at: nil
    )
  end
  private_class_method :mark_published!

  def self.record_kafka_publish!(message)
    sent_at = Time.current
    message.update!(
      kafka_sent_at: sent_at,
      status: "published",
      published_at: sent_at,
      last_error: nil,
      publishing_claimed_at: nil
    )
  rescue StandardError
    message.update!(kafka_sent_at: sent_at) if message.reload.kafka_sent_at.blank?
    raise
  end
  private_class_method :record_kafka_publish!

  def self.refresh_publishing_claim!(message)
    message.update_columns(publishing_claimed_at: Time.current) if message.persisted?
  end
  private_class_method :refresh_publishing_claim!

  def self.publish_with_rescue!(message)
    publish!(message)
  rescue StandardError => e
    ActiveSupport::Notifications.instrument(
      "platform_outbox.publish_failed",
      message_id: message.id,
      error_class: e.class.name,
      error_message: e.message
    )
  end
  private_class_method :publish_with_rescue!

  def self.mark_permanent_failed!(message, error_message)
    mark_failed!(message, error_message, permanent: true)
  end
  private_class_method :mark_permanent_failed!

  def self.mark_failed!(message, error_message, permanent: false)
    attrs = {
      status: "failed",
      last_error: error_message,
      publishing_claimed_at: nil
    }

    if permanent
      attrs[:permanent_failure] = true
    else
      attempts = message.publish_attempts + 1
      attrs[:publish_attempts] = attempts

      if attempts >= MAX_PUBLISH_ATTEMPTS
        attrs[:permanent_failure] = true
        attrs[:last_error] = "#{error_message} (max publish attempts exceeded)"
      else
        attrs[:permanent_failure] = false
      end
    end

    message.update!(attrs)
  end
  private_class_method :mark_failed!
end
