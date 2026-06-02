# frozen_string_literal: true

module Territory
  module Commands
    class LinkCitizenToHousehold < ApplicationCommand
      Result = Data.define(:household_member)

      def initialize(household:, citizen:, family_reference: false)
        @household = household
        @citizen = citizen
        @family_reference = family_reference
      end

      def call
        member = @household.household_members.create!(
          citizen: @citizen,
          family_reference: @family_reference
        )
        Result.new(household_member: member)
      end
    end
  end
end
