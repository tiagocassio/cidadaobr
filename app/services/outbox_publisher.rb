# frozen_string_literal: true

class OutboxPublisher
  TOPIC_MAPPING = {
    "platform.bootstrapped" => "domain.outbox",
    "citizen.registered" => "citizen.registered",
    "clinical.record.persisted" => "clinical.record.persisted"
  }.freeze

  def self.publish_pending!(limit: 100)
    OutboxMessage.pending.order(:created_at).limit(limit).find_each do |message|
      publish!(message)
    end
  end

  def self.publish!(message)
    producer = Karafka.producer
    producer.produce_sync(
      topic: message.topic,
      payload: message.payload.to_json,
      key: message.domain_event_id
    )

    message.update!(status: "published", published_at: Time.current, last_error: nil)
  rescue StandardError => e
    message.update!(status: "failed", last_error: e.message)
    raise
  end
end
