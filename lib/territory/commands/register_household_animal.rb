# frozen_string_literal: true

module Territory
  module Commands
    class RegisterHouseholdAnimal < ApplicationCommand
      Result = Data.define(:household_animal)

      def initialize(household:, attributes:)
        @household = household
        @attributes = attributes
      end

      def call
        animal = @household.household_animals.create!(@attributes)
        Result.new(household_animal: animal)
      end
    end
  end
end
