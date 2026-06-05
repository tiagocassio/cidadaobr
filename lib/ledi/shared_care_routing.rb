# frozen_string_literal: true

module Ledi
  module SharedCareRouting
    module_function

    def event_care_team_id(shared_care_case)
      return shared_care_case.origin_care_team_id if shared_care_case.origin_care_team_id.present?

      CitizenPortal::CareTeamRouting.resolve_care_team_id(shared_care_case.citizen)
    end
  end
end
