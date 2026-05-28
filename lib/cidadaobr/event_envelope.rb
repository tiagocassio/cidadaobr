# frozen_string_literal: true

module Cidadaobr
  EventEnvelope = Data.define(
    :event_id,
    :municipality_id,
    :health_facility_id,
    :care_team_id,
    :event_type,
    :payload,
    :occurred_at
  ) do
    def self.from_domain_event(event)
      new(
        event_id: event.id,
        municipality_id: event.municipality_id,
        health_facility_id: event.health_facility_id,
        care_team_id: event.care_team_id,
        event_type: event.event_type,
        payload: event.payload,
        occurred_at: event.occurred_at
      )
    end

    def to_h
      {
        event_id: event_id,
        municipality_id: municipality_id,
        health_facility_id: health_facility_id,
        care_team_id: care_team_id,
        event_type: event_type,
        payload: payload,
        occurred_at: occurred_at.iso8601
      }
    end
  end
end
