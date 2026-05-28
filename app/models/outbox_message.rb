# frozen_string_literal: true

class OutboxMessage < ApplicationRecord
  STATUSES = %w[pending publishing published failed].freeze

  # Loaded at boot; change env vars then restart app/worker.
  STALE_PUBLISHING_AFTER = ENV.fetch("OUTBOX_STALE_PUBLISHING_AFTER_SECONDS", 15.minutes.to_i).to_i.seconds
  FAILED_RETRY_AFTER = ENV.fetch("OUTBOX_FAILED_RETRY_AFTER_SECONDS", 5.minutes.to_i).to_i.seconds
  MAX_PUBLISH_ATTEMPTS = ENV.fetch("OUTBOX_MAX_PUBLISH_ATTEMPTS", 10).to_i
  DEFAULT_FAILED_RETRY_LIMIT = 50

  validates :domain_event_id, :municipality_id, :topic, :event_type, :status, presence: true
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
