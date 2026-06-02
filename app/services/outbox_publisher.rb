# frozen_string_literal: true

class OutboxPublisher
  STALE_PUBLISHING_AFTER = OutboxMessage::STALE_PUBLISHING_AFTER
  FAILED_RETRY_AFTER = OutboxMessage::FAILED_RETRY_AFTER
  DEFAULT_FAILED_RETRY_LIMIT = OutboxMessage::DEFAULT_FAILED_RETRY_LIMIT
  MAX_PUBLISH_ATTEMPTS = OutboxMessage::MAX_PUBLISH_ATTEMPTS
  RECLAIMED_STALE_MESSAGE = "Reclaimed stale publishing claim"

  TOPIC_MAPPING = Cidadaobr::KafkaTopics::EVENT_TO_TOPIC

  # Sweeps every municipality under RLS (O(municipalities) tenant switches per loop).
  # Claim order is per-tenant FIFO, not global cross-municipality FIFO.
  # Slow produce_sync blocks the worker; if send exceeds STALE_PUBLISHING_AFTER another
  # worker may reclaim and duplicate to Kafka (consumers dedupe on event_id). Tune via
  # OUTBOX_STALE_PUBLISHING_AFTER_SECONDS and restart the process after changing it.
  def self.publish_pending!(limit: 100, failed_retry_limit: DEFAULT_FAILED_RETRY_LIMIT)
    remaining = limit
    failed_requeue_remaining = failed_retry_limit
    municipality_ids = municipality_ids_by_oldest_pending

    loop do
      break if remaining <= 0
      break if municipality_ids.empty?

      progressed = false

      municipality_ids.each do |municipality_id|
        break if remaining <= 0

        with_municipal_tenant(municipality_id) do
          if failed_requeue_remaining.positive?
            requeued = requeue_retryable_failed!(limit: failed_requeue_remaining)
            failed_requeue_remaining -= requeued
          end
          reclaim_stale_publishing!

          message = claim_next_for_publish!
          next unless message

          progressed = true
          remaining -= 1
          publish_with_rescue!(message)
        end
      end

      break unless progressed

      municipality_ids = municipality_ids_by_oldest_pending
    end
  end

  def self.retry_failed!(limit: 100, force: false)
    remaining = limit
    skipped_permanent = 0
    forced_permanent = 0

    Municipality.find_each do |municipality|
      break if remaining <= 0

      with_municipal_tenant(municipality.id) do
        failed_scope = OutboxMessage.failed.order(:updated_at)
        batch = failed_scope.limit(remaining)
        unless force
          skipped_permanent += batch.where(permanent_failure: true).count
        end

        scope = force ? batch : batch.where(permanent_failure: false)
        ids = scope.pluck(:id)
        forced_permanent += OutboxMessage.where(id: ids, permanent_failure: true).count if force
        requeued = requeue_message_ids!(ids, reset_attempts: force)
        remaining -= requeued
      end
    end

    if force && forced_permanent.positive?
      Rails.logger.warn(
        "[OutboxPublisher] Force-requeued #{forced_permanent} permanently failed message(s); " \
        "publish_attempts reset — verify payload before retry"
      )
    end

    if !force && skipped_permanent.positive?
      Rails.logger.warn(
        "[OutboxPublisher] Skipped #{skipped_permanent} permanently failed message(s); " \
        "set OUTBOX_RETRY_FAILED_FORCE=true to requeue"
      )
    end
  end

  def self.municipality_ids_by_oldest_pending
    Municipality.order(:id).filter_map do |municipality|
      with_municipal_tenant(municipality.id) do
        next unless outbox_work_present?

        [ outbox_work_priority_timestamp, municipality.id ]
      end
    end.sort_by(&:first).map(&:last)
  end

  def self.outbox_work_present?
    OutboxMessage.pending.exists? ||
      OutboxMessage.stale_publishing.exists? ||
      OutboxMessage.where(status: "publishing").where.not(kafka_sent_at: nil).exists? ||
      OutboxMessage.retryable_failed.exists?
  end
  private_class_method :outbox_work_present?

  def self.outbox_work_priority_timestamp
    [
      OutboxMessage.pending.minimum(:created_at),
      OutboxMessage.stale_publishing_priority_timestamp,
      OutboxMessage.where(status: "publishing").where.not(kafka_sent_at: nil).minimum(:kafka_sent_at),
      OutboxMessage.retryable_failed.minimum(:updated_at)
    ].compact.min
  end
  private_class_method :outbox_work_priority_timestamp

  def self.reclaim_stale_publishing!(stale_after: STALE_PUBLISHING_AFTER)
    reclaimed = OutboxMessage.stale_publishing(stale_after: stale_after).update_all(
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

    Rails.logger.warn("[OutboxPublisher] Reclaimed #{reclaimed} stale publishing message(s)")
  end

  def self.requeue_retryable_failed!(retry_after: FAILED_RETRY_AFTER, limit: DEFAULT_FAILED_RETRY_LIMIT)
    ids = OutboxMessage.retryable_failed(retry_after: retry_after).order(:updated_at).limit(limit).pluck(:id)
    requeue_message_ids!(ids)
  end

  def self.requeue_message_ids!(ids, reset_attempts: false)
    return 0 if ids.empty?

    timestamp = Time.current
    requeued = 0
    shared_attrs = {
      status: "pending",
      last_error: nil,
      publishing_claimed_at: nil,
      permanent_failure: false,
      updated_at: timestamp
    }
    shared_attrs[:publish_attempts] = 0 if reset_attempts

    requeued = OutboxMessage.where(id: ids).update_all(shared_attrs)

    if requeued.positive?
      Rails.logger.info("[OutboxPublisher] Requeued #{requeued} failed message(s) for retry")
    end

    requeued
  end

  # Per-municipality FIFO; cross-municipality fairness comes from publish_pending! round-robin.
  def self.claim_next_for_publish!
    ActiveRecord::Base.transaction do
      message = OutboxMessage.pending.order(:created_at).limit(1).lock("FOR UPDATE SKIP LOCKED").first
      if message
        message.update!(
          status: "publishing",
          publishing_claimed_at: Time.current
        )
        return message
      end

      message = OutboxMessage.where(status: "publishing")
        .where.not(kafka_sent_at: nil)
        .order(:kafka_sent_at)
        .limit(1)
        .lock("FOR UPDATE SKIP LOCKED")
        .first
      message&.update_columns(publishing_claimed_at: Time.current)
      message
    end
  end

  # At-least-once to Kafka: a crash after produce_sync may leave status != published until
  # reclaim + retry sends a duplicate. ApplicationConsumer dedupes on envelope event_id.
  def self.publish!(message)
    message.reload
    return if message.status == "published"

    refresh_publishing_claim!(message) if message.status == "publishing"

    event_id = extract_event_id!(message)
    return if event_id.nil?

    unless event_id.to_s == message.domain_event_id.to_s
      mark_permanent_failed!(message, "Outbox payload event_id must match domain_event_id")
      raise ArgumentError, "Outbox payload event_id must match domain_event_id"
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
    return unless message.persisted?

    message.update_columns(publishing_claimed_at: Time.current)
  end
  private_class_method :refresh_publishing_claim!

  def self.publish_with_rescue!(message)
    publish!(message)
  rescue StandardError => e
    ActiveSupport::Notifications.instrument(
      "outbox.publish_failed",
      message_id: message.id,
      municipality_id: message.municipality_id,
      error_class: e.class.name,
      error_message: e.message
    )
  end
  private_class_method :publish_with_rescue!

  def self.with_municipal_tenant(municipality_id, &block)
    tenant = Cidadaobr::TenantScope.new(
      municipality_id: municipality_id,
      scope: "municipality",
      health_facility_id: nil,
      team_ids: [],
      citizen_id: nil
    )

    Cidadaobr::TenantContext.with(tenant, &block)
  end
  private_class_method :with_municipal_tenant

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
