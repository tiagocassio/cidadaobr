# frozen_string_literal: true

module Scheduling
  module Errors
    class SlotUnavailableError < StandardError; end
    class InvalidTransitionError < StandardError; end
  end
end
