# frozen_string_literal: true

module Territory
  module Commands
    class UpdateCareTeam < ApplicationCommand
      Result = Data.define(:success, :care_team)

      def initialize(care_team:, attributes:)
        @care_team = care_team
        @attributes = attributes
      end

      def call
        success = @care_team.update(@attributes)
        emit_updated!(@care_team) if success
        Result.new(success: success, care_team: @care_team)
      end

      private

      def emit_updated!(team)
        RecordPlatformEvent.call(
          event_type: Cidadaobr::KafkaTopics::CARE_TEAM_UPDATED,
          aggregate_type: "CareTeam",
          aggregate_id: team.id,
          payload: {
            care_team_id: team.id,
            health_facility_id: team.health_facility_id,
            team_kind: team.team_kind
          },
          care_team_id: team.id
        )
      end
    end
  end
end
