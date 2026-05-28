# frozen_string_literal: true

class PublishOutboxMessagesJob < ApplicationJob
  queue_as :default

  # Safe to overlap with outbox:publish or a second worker: claim uses FOR UPDATE SKIP LOCKED.
  def perform
    OutboxPublisher.publish_pending!
  end
end
