# frozen_string_literal: true

module Ledi
  class RecordSharedCareEvolution < ApplicationCommand
    def initialize(shared_care_case:, evolution_note:, author_user: nil, status: "documented")
      @shared_care_case = shared_care_case
      @evolution_note = evolution_note
      @author_user = author_user
      @status = status
    end

    def call
      tenant = Cidadaobr::TenantContext.current_or_raise!
      if @shared_care_case.municipality_id != tenant.municipality_id
        raise ArgumentError, "shared care case municipality mismatch"
      end
      unless SharedCareCaseTenantAccess.accessible?(@shared_care_case, tenant)
        raise ArgumentError, "shared care case not accessible in current scope"
      end

      write_transaction do
        evolution = @shared_care_case.shared_care_evolutions.create!(
          author_user: @author_user,
          evolution_note: @evolution_note,
          status: @status
        )

        RecordPlatformEvent.call(
          event_type: Cidadaobr::KafkaTopics::SHARED_CARE_EVOLUTION_RECORDED,
          aggregate_type: "SharedCareCase",
          aggregate_id: @shared_care_case.id,
          payload: {
            shared_care_case_id: @shared_care_case.id,
            shared_care_evolution_id: evolution.id,
            author_user_id: evolution.author_user_id,
            status: evolution.status
          },
          care_team_id: SharedCareRouting.event_care_team_id(@shared_care_case)
        )

        evolution
      end
    end
  end
end
