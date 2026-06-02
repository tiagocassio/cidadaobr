# frozen_string_literal: true

class RecordPlatformEvent < ApplicationCommand
  AGGREGATE_VERSION_INDEX = "index_domain_events_on_aggregate_version"

  def initialize(event_type:, aggregate_type:, aggregate_id:, payload:, topic: nil, metadata: {}, care_team_id: nil)
    @event_type = event_type
    @aggregate_type = aggregate_type
    @aggregate_id = aggregate_id
    @payload = payload
    @topic = topic || event_type
    @metadata = metadata
    @care_team_id = care_team_id
  end

  def call
    tenant = Cidadaobr::TenantContext.current_or_raise!
    care_team_id = @care_team_id || tenant_care_team_id(tenant)

    append_with_version_retry(tenant: tenant, care_team_id: care_team_id)
  end

  private

  def append_with_version_retry(tenant:, care_team_id:, attempts: 3)
    attempt = 0

    begin
      attempt += 1

      with_optional_transaction do
        version = DomainEvent.where(aggregate_type: @aggregate_type, aggregate_id: @aggregate_id).maximum(:version).to_i + 1

        event = DomainEvent.append!(
          aggregate_type: @aggregate_type,
          aggregate_id: @aggregate_id,
          event_type: @event_type,
          payload: @payload,
          metadata: @metadata,
          occurred_at: Time.current,
          version: version,
          municipality_id: tenant.municipality_id,
          health_facility_id: tenant.health_facility_id,
          care_team_id: care_team_id
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
    rescue ActiveRecord::RecordNotUnique => e
      raise unless aggregate_version_collision?(e)
      raise if attempt >= attempts

      retry
    end
  end

  def with_optional_transaction(&block)
    if ActiveRecord::Base.connection.open_transactions.positive?
      Cidadaobr::TenantRls.apply_write_scope!
      yield
    else
      Cidadaobr::TenantRls.write_transaction(&block)
    end
  end

  def aggregate_version_collision?(error)
    Cidadaobr::PgUniqueConstraint.match?(error, AGGREGATE_VERSION_INDEX)
  end

  def tenant_care_team_id(tenant)
    return unless tenant.scope == "team"

    case tenant.team_ids.size
    when 0
      raise Ledi::Errors::AmbiguousTeamScopeError, "Team scope requires at least one assigned care team"
    when 1
      tenant.team_ids.sole
    else
      raise Ledi::Errors::AmbiguousTeamScopeError, "Team scope requires exactly one care team when care_team_id is omitted"
    end
  end
end
