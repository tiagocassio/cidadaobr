# frozen_string_literal: true

module Indicators
  module Errors
    class SkippableRecalculationError < StandardError; end

    class AppointmentOutsideTenantError < SkippableRecalculationError; end

    class TeamContextRequiredError < ArgumentError; end

    class UnknownCareTeamError < ArgumentError; end
  end
end
