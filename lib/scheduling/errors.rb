# frozen_string_literal: true

module Scheduling
  module Errors
    class SlotUnavailableError < StandardError
      CODES = {
        slot_time_mismatch: "Scheduled time does not match selected slot",
        slot_room_mismatch: "Slot does not belong to the selected room",
        slot_not_found: "Slot not found",
        slot_full: "No capacity remaining for slot",
        slot_release_failed: "Could not release slot capacity",
        slot_appointment_mismatch: "Slot does not belong to this appointment",
        outside_municipality: "Booking data is outside the current municipality",
        citizen_missing_facility: "Citizen must be linked to a health facility before booking",
        citizen_facility_mismatch: "Citizen is not linked to the selected facility",
        care_team_citizen_mismatch: "Care team is not linked to the citizen",
        care_team_facility_mismatch: "Care team is not linked to the selected facility",
        slot_belongs_to_another_room: "Slot belongs to another room"
      }.freeze

      attr_reader :code

      def initialize(message = nil, code: nil)
        @code = code&.to_sym
        if @code
          super(CODES.fetch(@code))
        else
          @code = CODES.key(message.to_s)
          super(message)
        end
      end

      def self.raise!(code)
        raise new(code: code)
      end
    end

    class InvalidTransitionError < StandardError; end
  end
end
