# frozen_string_literal: true

module Web
  module Stock
    class ImmunobiologicalLotsController < BaseController
      before_action :require_facility_or_municipality!
      before_action :require_facility_or_municipality_write!, only: %i[new create]
      before_action :set_products, only: %i[new create]

      def index
        @pagy, @lots = pagy(
          scoped_lots.includes(:immunobiological_product, :health_facility).order(expires_on: :asc)
        )
      end

      def new
        @lot = scoped_lots.build(expires_on: 6.months.from_now.to_date)
      end

      def create
        @lot = scoped_lots.build(lot_params)
        @lot.municipality = current_municipality

        if add_scoped_param_errors(@lot, raw_facility_id: params.dig(:immunobiological_lot, :health_facility_id))
          render :new, status: :unprocessable_entity
          return
        end

        ActiveRecord::Base.transaction do
          if @lot.save
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

            redirect_to web_stock_immunobiological_lots_path, notice: t("cidadaobr.stock.lots.flash.created")
          else
            render :new, status: :unprocessable_entity
          end
        end
      end

      private

      def scoped_lots
        scope = ImmunobiologicalLot.where(municipality_id: current_municipality.id)
        return scope if municipality_scope?

        scope.where(health_facility_id: scoped_health_facilities.select(:id))
      end

      def set_products
        @products = ImmunobiologicalProduct.where(municipality_id: current_municipality.id, active: true).order(:name)
        @facilities = scoped_health_facilities.order(:name)
      end

      def lot_params
        permitted = params.require(:immunobiological_lot).permit(
          :health_facility_id,
          :immunobiological_product_id,
          :lot_number,
          :expires_on,
          :manufacturer,
          :quantity_on_hand
        )
        permitted[:health_facility_id] = sanitize_scoped_health_facility_id(permitted[:health_facility_id])
        permitted
      end
    end
  end
end
