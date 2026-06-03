# frozen_string_literal: true

module Web
  module Stock
    class ImmunobiologicalProductsController < BaseController
      before_action :require_facility_or_municipality!
      before_action :require_facility_or_municipality_write!, only: %i[new create edit update]
      before_action :set_product, only: %i[edit update]

      def index
        @pagy, @products = pagy(
          ImmunobiologicalProduct.where(municipality_id: current_municipality.id).order(:name)
        )
      end

      def new
        @product = ImmunobiologicalProduct.new(active: true, target_species: "human")
      end

      def create
        @product = ImmunobiologicalProduct.new(product_params)
        result = CommandBus.dispatch(
          Inventory::Commands::CreateImmunobiologicalProduct,
          product: @product,
          municipality: current_municipality
        )
        @product = result.product

        if result.success
          redirect_to web_stock_immunobiological_products_path, notice: t("cidadaobr.stock.products.flash.created")
        else
          render :new, status: :unprocessable_entity
        end
      end

      def edit; end

      def update
        result = CommandBus.dispatch(
          Inventory::Commands::UpdateImmunobiologicalProduct,
          product: @product,
          attributes: product_params
        )
        @product = result.product

        if result.success
          redirect_to web_stock_immunobiological_products_path, notice: t("cidadaobr.stock.products.flash.updated")
        else
          render :edit, status: :unprocessable_entity
        end
      end

      private

      def set_product
        @product = ImmunobiologicalProduct.where(municipality_id: current_municipality.id).find(params[:id])
      end

      def product_params
        params.expect(immunobiological_product: %i[code name target_species active])
      end
    end
  end
end
