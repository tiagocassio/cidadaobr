# frozen_string_literal: true

module Inventory
  module Commands
    class UpdateImmunobiologicalProduct < ApplicationCommand
      Result = Data.define(:success, :product)

      def initialize(product:, attributes:)
        @product = product
        @attributes = attributes
      end

      def call
        success = @product.update(@attributes)
        Result.new(success: success, product: @product)
      end
    end
  end
end
