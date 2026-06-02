# frozen_string_literal: true

module Inventory
  module Commands
    class CreateSupplyItem < ApplicationCommand
      Result = Data.define(:success, :item)

      def initialize(item:, municipality:, components: [])
        @item = item
        @municipality = municipality
        @components = Array(components)
      end

      def call
        @item.municipality = @municipality
        success = false
        rolled_back = false

        write_transaction do
          unless @item.save
            next
          end

          if @item.composite? && !sync_components!
            rolled_back = true
            raise ActiveRecord::Rollback
          end

          success = @item.errors.empty?
        end

        reset_item_after_rolled_back_create! if rolled_back

        Result.new(success: success, item: @item)
      end

      private

      def sync_components!
        Inventory::SupplyItemComponentSync.new(
          item: @item,
          municipality_id: @municipality.id,
          components: @components
        ).apply!(municipality: @municipality)
      end

      def reset_item_after_rolled_back_create!
        attributes = @item.attributes.except("id", "created_at", "updated_at")
        errors = @item.errors.errors.dup
        @item = SupplyItem.new(attributes)
        @item.municipality = @municipality
        errors.each { |error| @item.errors.import(error) }
      end
    end
  end
end
