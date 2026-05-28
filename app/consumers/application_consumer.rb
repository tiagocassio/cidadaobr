# frozen_string_literal: true

class ApplicationConsumer < Karafka::BaseConsumer
  private

  def process_with_idempotency(message, consumer_group: KarafkaApp.config.client_id)
    payload = parse_envelope!(message.payload)
    event_id = payload.fetch("event_id")

    tenant = Cidadaobr::TenantScope.from_envelope(payload)
    Cidadaobr::TenantContext.with(tenant) do
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
    end

    :processed
  rescue InvalidEventEnvelopeError => e
    Rails.logger.error("[Kafka] poison envelope skipped: #{e.message}")
    mark_as_consumed(message)
    :invalid
  rescue ActiveRecord::RecordNotUnique => e
    raise unless duplicate_idempotency_violation?(e)

    :duplicate
  end

  def acquire_idempotency_lock!(event_id, consumer_group)
    connection = ActiveRecord::Base.connection
    lock_key = "#{consumer_group}:#{topic.name}:#{event_id}"
    connection.execute(
      "SELECT pg_advisory_xact_lock(hashtextextended(#{connection.quote(lock_key)}, 0))"
    )
  end

  def duplicate_idempotency_violation?(error)
    Cidadaobr::PgUniqueConstraint.match?(error, "index_kafka_processed_events_on_idempotency")
  end

  def parse_envelope!(raw_payload)
    payload = JSON.parse(raw_payload)
    payload.fetch("event_id")
    payload.fetch("municipality_id")
    payload
  rescue JSON::ParserError => e
    raise InvalidEventEnvelopeError, "Invalid event envelope JSON: #{e.message}"
  rescue KeyError => e
    raise InvalidEventEnvelopeError, "Invalid event envelope: missing #{e.key}"
  end
end
