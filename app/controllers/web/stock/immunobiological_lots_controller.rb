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

        if scoped_lot_param_errors?
          render :new, status: :unprocessable_entity
          return
        end

        result = CommandBus.dispatch(Inventory::Commands::ReceiveImmunobiologicalLot, lot: @lot)
        if result.success
          redirect_to web_stock_immunobiological_lots_path, notice: t("cidadaobr.stock.lots.flash.created")
        else
          render :new, status: :unprocessable_entity
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
        immunobiological_lot_permitted
      end

      def scoped_lot_param_errors?
        permitted = immunobiological_lot_permitted
        add_scoped_param_errors(
          @lot,
          raw_facility_id: permitted[:health_facility_id],
          health_facility_id: permitted[:health_facility_id]
        )
      end

      def immunobiological_lot_permitted
        return @immunobiological_lot_permitted if defined?(@immunobiological_lot_permitted)

        @immunobiological_lot_permitted = params.expect(
          immunobiological_lot: %i[
            health_facility_id
            immunobiological_product_id
            lot_number
            expires_on
            manufacturer
            quantity_on_hand
          ]
        )
        @immunobiological_lot_permitted[:health_facility_id] =
          sanitize_scoped_health_facility_id(@immunobiological_lot_permitted[:health_facility_id])
        @immunobiological_lot_permitted
      end
    end
  end
end
