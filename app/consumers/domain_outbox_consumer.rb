# frozen_string_literal: true

class DomainOutboxConsumer < ApplicationConsumer
  def consume
    messages.each do |message|
      process_with_idempotency(message) do |_payload|
        Rails.logger.info("[Kafka] domain.outbox processed")
      end
    end
  end
end
