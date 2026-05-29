# frozen_string_literal: true

module Indicators
  module Errors
    class SkippableRecalculationError < StandardError; end

    class AppointmentOutsideTenantError < SkippableRecalculationError; end
  end
end
