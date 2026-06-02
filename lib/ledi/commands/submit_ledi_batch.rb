# frozen_string_literal: true

module Ledi
  class SubmitLediBatch < ApplicationCommand
    def initialize(batch_number: nil)
      @batch_number = batch_number
    end

    def call
      tenant = Cidadaobr::TenantContext.current_or_raise!
      ledi_version = Rails.application.config.ledi.fetch(:version)
      team_id = team_id_for_batch(tenant)

      write_transaction do
        transport_records = scoped_validated_transport_records(tenant, team_id: team_id)
        raise Errors::EmptyBatchError, "No validated transport records available for batch submission" if transport_records.none?

        batch_number = @batch_number || next_batch_number(tenant, team_id: team_id)
        batch = LediBatch.create!(
          municipality_id: tenant.municipality_id,
          health_facility_id: tenant.scope == "facility" ? tenant.health_facility_id : nil,
          care_team_id: team_id,
          batch_number: batch_number,
          ledi_version: ledi_version,
          status: "ready",
          submitted_at: Time.current
        )

        transport_records.update_all(ledi_batch_id: batch.id, batch_number: batch_number, updated_at: Time.current)

        RecordPlatformEvent.call(
          event_type: Cidadaobr::KafkaTopics::LEDI_BATCH_SUBMITTED,
          aggregate_type: "LediBatch",
          aggregate_id: batch.id,
          payload: {
            ledi_batch_id: batch.id,
            batch_number: batch.batch_number,
            transport_record_ids: transport_records.pluck(:id),
            ledi_version: batch.ledi_version
          },
          care_team_id: batch.care_team_id
        )

        batch
      end
    end

    private

    def team_id_for_batch(tenant)
      return unless tenant.scope == "team"

      case tenant.team_ids.size
      when 0
        raise Errors::AmbiguousTeamScopeError, "Team scope requires at least one assigned care team"
      when 1
        tenant.team_ids.sole
      else
        raise Errors::AmbiguousTeamScopeError, "Team scope batch submission requires exactly one care team"
      end
    end

    def scoped_validated_transport_records(tenant, team_id:)
      scope = TransportRecord.where(
        municipality_id: tenant.municipality_id,
        status: "validated",
        ledi_batch_id: nil
      )

      case tenant.scope
      when "facility"
        scope = scope.where(health_facility_id: tenant.health_facility_id)
      when "team"
        scope = scope.where(care_team_id: team_id)
      end

      scope.lock
    end

    def next_batch_number(tenant, team_id:)
      scope = LediBatch.where(municipality_id: tenant.municipality_id)

      case tenant.scope
      when "facility"
        scope = scope.where(health_facility_id: tenant.health_facility_id)
      when "team"
        scope = scope.where(care_team_id: team_id)
      when "municipality"
        scope = scope.where(health_facility_id: nil, care_team_id: nil)
      end

      (scope.maximum(:batch_number) || 0) + 1
    end
  end
end
