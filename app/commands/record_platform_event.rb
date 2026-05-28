# frozen_string_literal: true

class RecordPlatformEvent < ApplicationCommand
  def initialize(event_type:, aggregate_type:, aggregate_id:, payload:, topic:, metadata: {})
    @event_type = event_type
    @aggregate_type = aggregate_type
    @aggregate_id = aggregate_id
    @payload = payload
    @topic = topic
    @metadata = metadata
  end

  def call
    tenant = Cidadaobr::TenantContext.current_or_raise!

    ActiveRecord::Base.transaction do
      version = DomainEvent.where(aggregate_type: @aggregate_type, aggregate_id: @aggregate_id).count + 1

      event = DomainEvent.append!(
        aggregate_type: @aggregate_type,
        aggregate_id: @aggregate_id,
        event_type: @event_type,
        payload: @payload,
        metadata: @metadata,
        occurred_at: Time.current,
        version: version,
        municipality_id: tenant.municipality_id,
        health_facility_id: tenant.health_facility_id
      )

      OutboxMessage.create!(
        domain_event_id: event.id,
        municipality_id: event.municipality_id,
        health_facility_id: event.health_facility_id,
        topic: @topic,
        event_type: event.event_type,
        payload: Cidadaobr::EventEnvelope.from_domain_event(event).to_h,
        status: "pending"
      )

      event
    end
  end
end
