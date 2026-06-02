# frozen_string_literal: true

module Inventory
  module Commands
    class ReceiveImmunobiologicalLot < ApplicationCommand
      Result = Data.define(:success, :lot)

      def initialize(lot:)
        @lot = lot
      end

      def call
        write_transaction do
          unless @lot.save
            raise ActiveRecord::Rollback
          end

          StockMovement.create!(
            municipality: @lot.municipality,
            health_facility: @lot.health_facility,
            immunobiological_lot: @lot,
            movement_type: "inbound",
            quantity: @lot.quantity_on_hand,
            reference_type: @lot.class.name,
            reference_id: @lot.id,
            notes: "Initial lot receipt"
          )

          emit_received!(@lot)
        end

        Result.new(success: @lot.persisted? && @lot.errors.none?, lot: @lot)
      end

      private

      def emit_received!(lot)
        RecordPlatformEvent.call(
          event_type: Cidadaobr::KafkaTopics::IMMUNOBIOLOGICAL_LOT_RECEIVED,
          aggregate_type: "ImmunobiologicalLot",
          aggregate_id: lot.id,
          payload: {
            lot_id: lot.id,
            health_facility_id: lot.health_facility_id,
            immunobiological_product_id: lot.immunobiological_product_id,
            quantity: lot.quantity_on_hand
          },
)
      end
    end
  end
end
