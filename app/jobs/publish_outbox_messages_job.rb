# frozen_string_literal: true

class PublishOutboxMessagesJob < ApplicationJob
  queue_as :default

  def perform
    OutboxPublisher.publish_pending!
  end
end
