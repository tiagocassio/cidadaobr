# frozen_string_literal: true

class PlatformOutboxMessage < ApplicationRecord
  STATUSES = OutboxMessage::STATUSES
  STALE_PUBLISHING_AFTER = OutboxMessage::STALE_PUBLISHING_AFTER
  FAILED_RETRY_AFTER = OutboxMessage::FAILED_RETRY_AFTER
  MAX_PUBLISH_ATTEMPTS = OutboxMessage::MAX_PUBLISH_ATTEMPTS
  DEFAULT_FAILED_RETRY_LIMIT = OutboxMessage::DEFAULT_FAILED_RETRY_LIMIT

  validates :platform_event_id, :topic, :event_type, :status, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :pending, -> { where(status: "pending") }
  scope :failed, -> { where(status: "failed") }
  scope :stale_publishing, ->(stale_after: STALE_PUBLISHING_AFTER) {
    threshold = stale_after.ago
    where(status: "publishing").where(
      "publishing_claimed_at < :threshold OR (publishing_claimed_at IS NULL AND updated_at < :threshold)",
      threshold: threshold
    )
  }
  scope :retryable_failed, ->(retry_after: FAILED_RETRY_AFTER) {
    failed
      .where(permanent_failure: false)
      .where(updated_at: ...retry_after.ago)
      .where(publish_attempts: ...MAX_PUBLISH_ATTEMPTS)
  }

  def self.stale_publishing_priority_timestamp(stale_after: STALE_PUBLISHING_AFTER)
    stale_publishing(stale_after: stale_after)
      .pick(Arel.sql("MIN(COALESCE(publishing_claimed_at, updated_at))"))
  end
end
