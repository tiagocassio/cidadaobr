# frozen_string_literal: true

class RecordGlobalPlatformEvent < ApplicationCommand
  AGGREGATE_VERSION_INDEX = "index_platform_events_on_aggregate_version"

  def initialize(event_type:, aggregate_type:, aggregate_id:, payload:, topic: nil, metadata: {})
    @event_type = event_type
    @aggregate_type = aggregate_type
    @aggregate_id = aggregate_id
    @payload = payload
    @topic = topic || event_type
    @metadata = metadata
  end

  def call
    append_with_version_retry
  end

  private

  def append_with_version_retry(attempts: 3)
    attempt = 0

    begin
      attempt += 1

      write_transaction do
        version = PlatformEvent.where(
          aggregate_type: @aggregate_type,
          aggregate_id: @aggregate_id
        ).maximum(:version).to_i + 1

        event = PlatformEvent.append!(
          aggregate_type: @aggregate_type,
          aggregate_id: @aggregate_id,
          event_type: @event_type,
          payload: @payload,
          metadata: @metadata,
          occurred_at: Time.current,
          version: version
        )

        PlatformOutboxMessage.create!(
          platform_event_id: event.id,
          topic: @topic,
          event_type: event.event_type,
          payload: Cidadaobr::EventEnvelope.from_platform_event(event).to_h,
          status: "pending"
        )

        event
      end
    rescue ActiveRecord::RecordNotUnique => e
      raise unless aggregate_version_collision?(e)
      raise if attempt >= attempts

      retry
    end
  end

  def aggregate_version_collision?(error)
    Cidadaobr::PgUniqueConstraint.match?(error, AGGREGATE_VERSION_INDEX)
  end
end
