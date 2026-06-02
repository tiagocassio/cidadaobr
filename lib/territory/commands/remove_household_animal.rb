# frozen_string_literal: true

module Territory
  module Commands
    class RemoveHouseholdAnimal < ApplicationCommand
      def initialize(household_animal:)
        @household_animal = household_animal
      end

      def call
        @household_animal.destroy!
      end
    end
  end
end
