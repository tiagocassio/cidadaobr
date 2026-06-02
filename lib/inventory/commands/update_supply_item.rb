# frozen_string_literal: true

module Inventory
  module Commands
    class UpdateSupplyItem < ApplicationCommand
      Result = Data.define(:success, :item)

      def initialize(item:, attributes:, components: [])
        @item = item
        @attributes = attributes
        @components = Array(components)
      end

      def call
        success = false
        rolled_back = false

        write_transaction do
          unless @item.update(@attributes)
            next
          end

          if @item.composite?
            unless sync_components!
              rolled_back = true
              raise ActiveRecord::Rollback
            end
          else
            @item.supply_item_components.destroy_all
          end

          success = @item.errors.empty?
        end

        restore_item_for_form! if rolled_back

        Result.new(success: success, item: @item)
      end

      private

      def sync_components!
        Inventory::SupplyItemComponentSync.new(
          item: @item,
          municipality_id: @item.municipality_id,
          components: @components,
          exclude_item_id: @item.id
        ).apply!(municipality: @item.municipality)
      end

      def restore_item_for_form!
        return unless @item.persisted?

        submitted = @attributes.stringify_keys
        preserved_errors = @item.errors.errors.dup
        @item.reload
        @item.assign_attributes(submitted)
        preserved_errors.each { |error| @item.errors.import(error) }
      end
    end
  end
end
