# frozen_string_literal: true

class ReferenceDataReleasePublishedConsumer < ApplicationConsumer
  def consume
    messages.each do |message|
      process_with_platform_idempotency(message) do |payload|
        release_key = payload.dig("payload", "release_key") || payload["release_key"]
        Rails.logger.info(
          "[Kafka] reference.release.published release_key=#{release_key.inspect}"
        )
      end
    end
  end

  private

  def process_with_platform_idempotency(message, consumer_group: KarafkaApp.config.client_id)
    payload = parse_platform_envelope!(message.payload)
    event_id = payload.fetch("event_id")

    ActiveRecord::Base.transaction do
      acquire_idempotency_lock!(event_id, consumer_group)

      if KafkaProcessedEvent.exists?(event_id: event_id, topic: topic.name, consumer_group: consumer_group)
        return :duplicate
      end

      yield payload

      KafkaProcessedEvent.create!(
        event_id: event_id,
        topic: topic.name,
        consumer_group: consumer_group,
        processed_at: Time.current
      )
    end

    :processed
  rescue InvalidEventEnvelopeError => e
    Rails.logger.error("[Kafka] poison platform envelope skipped: #{e.message}")
    mark_as_consumed(message)
    :invalid
  rescue ActiveRecord::RecordNotUnique => e
    raise unless duplicate_idempotency_violation?(e)

    :duplicate
  end

  def parse_platform_envelope!(raw_payload)
    payload = JSON.parse(raw_payload)
    payload.fetch("event_id")
    payload.fetch("event_type")
    payload
  rescue JSON::ParserError => e
    raise InvalidEventEnvelopeError, "Invalid event envelope JSON: #{e.message}"
  rescue KeyError => e
    raise InvalidEventEnvelopeError, "Invalid platform envelope: missing #{e.key}"
  end
end
