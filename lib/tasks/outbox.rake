# frozen_string_literal: true

namespace :outbox do
  desc "Publish pending outbox messages to Kafka"
  task publish: :environment do
    OutboxPublisher.publish_pending!
  end

  desc "Requeue failed outbox messages (OUTBOX_RETRY_FAILED_FORCE=true requeues permanent failures and resets attempts)"
  task retry_failed: :environment do
    force = ActiveModel::Type::Boolean.new.cast(ENV.fetch("OUTBOX_RETRY_FAILED_FORCE", false))
    OutboxPublisher.retry_failed!(force: force)
  end
end
