# frozen_string_literal: true

# Placeholder until scheduling and clinical-record business handlers exist. PRODUCTION: do not route real
# appointment/ledi side effects here — offsets advance after log-only ack. Wire handlers
# before enabling dependent workflows (notifications, analytics, external sync).
class PlatformEventConsumer < ApplicationConsumer
  def consume
    messages.each do |message|
      process_with_idempotency(message) do |payload|
        event_type = payload["event_type"] || payload.dig("payload", "event_type")
        aggregate_id = payload["aggregate_id"] || payload.dig("payload", "aggregate_id")

        Rails.logger.info(
          "[Kafka] #{topic.name} placeholder consumer (no business handler yet) " \
          "event_type=#{event_type.inspect} aggregate_id=#{aggregate_id.inspect}"
        )
      end
    end
  end
end
