# frozen_string_literal: true

module Territory
  module Commands
    class UnlinkHouseholdMember < ApplicationCommand
      def initialize(household_member:)
        @household_member = household_member
      end

      def call
        @household_member.destroy!
      end
    end
  end
end
