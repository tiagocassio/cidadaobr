# frozen_string_literal: true

module Inventory
  module Commands
    class CreateImmunobiologicalProduct < ApplicationCommand
      Result = Data.define(:success, :product)

      def initialize(product:, municipality:)
        @product = product
        @municipality = municipality
      end

      def call
        @product.municipality = @municipality
        success = @product.save
        Result.new(success: success, product: @product)
      end
    end
  end
end
