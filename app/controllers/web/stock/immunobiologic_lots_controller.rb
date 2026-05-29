# frozen_string_literal: true

module Web
  module Stock
    class ImmunobiologicLotsController < BaseController
      before_action :require_facility_or_municipality!
      before_action :require_facility_or_municipality_write!, only: %i[new create]
      before_action :set_products, only: %i[new create]

      def index
        @pagy, @lots = pagy(
          scoped_lots.includes(:immunobiologic_product, :health_facility).order(expires_on: :asc)
        )
      end

      def new
        @lot = scoped_lots.build(expires_on: 6.months.from_now.to_date)
      end

      def create
        @lot = scoped_lots.build(lot_params)
        @lot.municipality = current_municipality

        ActiveRecord::Base.transaction do
          if @lot.save
            StockBalance.find_or_initialize_by(
              municipality: @lot.municipality,
              health_facility: @lot.health_facility,
              immunobiologic_lot: @lot
            ).update!(quantity: @lot.quantity_on_hand)

            StockMovement.create!(
              municipality: @lot.municipality,
              health_facility: @lot.health_facility,
              immunobiologic_lot: @lot,
              movement_type: "inbound",
              quantity: @lot.quantity_on_hand,
              reference_type: @lot.class.name,
              reference_id: @lot.id,
              notes: "Initial lot receipt"
            )

            redirect_to web_stock_immunobiologic_lots_path, notice: t("cidadaobr.stock.lots.flash.created")
          else
            render :new, status: :unprocessable_entity
          end
        end
      end

      private

      def scoped_lots
        scope = ImmunobiologicLot.where(municipality_id: current_municipality.id)
        return scope if municipality_scope?

        scope.where(health_facility_id: scoped_health_facilities.select(:id))
      end

      def set_products
        @products = ImmunobiologicProduct.where(municipality_id: current_municipality.id, active: true).order(:name)
        @facilities = scoped_health_facilities.order(:name)
      end

      def lot_params
        params.require(:immunobiologic_lot).permit(
          :health_facility_id,
          :immunobiologic_product_id,
          :lot_number,
          :expires_on,
          :manufacturer,
          :quantity_on_hand
        )
      end
    end
  end
end
