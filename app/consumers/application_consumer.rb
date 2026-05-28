# frozen_string_literal: true

class ApplicationConsumer < Karafka::BaseConsumer
  private

  def process_with_idempotency(message, consumer_group: KarafkaApp.config.client_id)
    payload = JSON.parse(message.payload)
    event_id = payload.fetch("event_id")

    return if KafkaProcessedEvent.exists?(event_id: event_id, topic: topic.name, consumer_group: consumer_group)

    yield payload

    KafkaProcessedEvent.create!(
      event_id: event_id,
      topic: topic.name,
      consumer_group: consumer_group,
      processed_at: Time.current
    )
  end
end
