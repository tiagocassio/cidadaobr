# frozen_string_literal: true

module Territory
  module Commands
    class CreateCareTeam < ApplicationCommand
      Result = Data.define(:success, :care_team)

      def initialize(care_team:, attributes:, municipality:)
        @care_team = care_team
        @attributes = attributes
        @municipality = municipality
      end

      def call
        @care_team.assign_attributes(@attributes)
        @care_team.municipality = @municipality
        success = @care_team.save
        emit_created!(@care_team) if success
        Result.new(success: success, care_team: @care_team)
      end

      private

      def emit_created!(team)
        RecordPlatformEvent.call(
          event_type: Cidadaobr::KafkaTopics::CARE_TEAM_CREATED,
          aggregate_type: "CareTeam",
          aggregate_id: team.id,
          payload: {
            care_team_id: team.id,
            health_facility_id: team.health_facility_id,
            team_kind: team.team_kind,
            ine: team.ine
          },
          care_team_id: team.id
        )
      end
    end
  end
end
