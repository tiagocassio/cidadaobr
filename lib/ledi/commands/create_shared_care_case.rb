# frozen_string_literal: true

module Ledi
  class CreateSharedCareCase < ApplicationCommand
    def initialize(citizen_id:, ciap2_code: nil, cid10_code: nil, clinical_summary: nil, origin_care_team_id: nil)
      @citizen_id = citizen_id
      @ciap2_code = ciap2_code
      @cid10_code = cid10_code
      @clinical_summary = clinical_summary
      @origin_care_team_id = origin_care_team_id
    end

    def call
      tenant = Cidadaobr::TenantContext.current_or_raise!

      write_transaction do
        citizen = Citizen.find_by(id: @citizen_id, municipality_id: tenant.municipality_id)
        unless citizen && SharedCareCaseTenantAccess.citizen_accessible?(citizen, tenant)
          raise ArgumentError, "citizen not accessible in current scope"
        end

        origin_care_team_id = resolve_origin_care_team_id(citizen, tenant)
        shared_care_case = SharedCareCase.create!(
          municipality_id: tenant.municipality_id,
          citizen_id: citizen.id,
          origin_care_team_id: origin_care_team_id,
          ciap2_code: @ciap2_code,
          cid10_code: @cid10_code,
          clinical_summary: @clinical_summary,
          status: "open"
        )

        RecordPlatformEvent.call(
          event_type: Cidadaobr::KafkaTopics::SHARED_CARE_CASE_CREATED,
          aggregate_type: "SharedCareCase",
          aggregate_id: shared_care_case.id,
          payload: {
            shared_care_case_id: shared_care_case.id,
            citizen_id: shared_care_case.citizen_id,
            origin_care_team_id: shared_care_case.origin_care_team_id,
            status: shared_care_case.status
          },
          care_team_id: shared_care_case.origin_care_team_id
        )

        shared_care_case
      end
    end

    private

    def resolve_origin_care_team_id(citizen, tenant)
      if @origin_care_team_id.present?
        team = CareTeam.find_by(id: @origin_care_team_id, municipality_id: citizen.municipality_id)
        raise ArgumentError, "origin care team not found" unless team
        unless SharedCareCaseTenantAccess.care_team_accessible?(team, tenant)
          raise ArgumentError, "origin care team not accessible in current scope"
        end

        return team.id
      end

      CitizenPortal::CareTeamRouting.resolve_care_team_id(citizen)
    end
  end
end
