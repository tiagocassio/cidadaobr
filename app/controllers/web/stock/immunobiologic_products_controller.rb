# frozen_string_literal: true

module Web
  module Stock
    class ImmunobiologicProductsController < BaseController
      before_action :require_facility_or_municipality!
      before_action :require_facility_or_municipality_write!, only: %i[new create edit update]
      before_action :set_product, only: %i[edit update]

      def index
        @pagy, @products = pagy(
          ImmunobiologicProduct.where(municipality_id: current_municipality.id).order(:name)
        )
      end

      def new
        @product = ImmunobiologicProduct.new(active: true, target_species: "human")
      end

      def create
        @product = ImmunobiologicProduct.new(product_params)
        @product.municipality = current_municipality

        if @product.save
          redirect_to web_stock_immunobiologic_products_path, notice: t("cidadaobr.stock.products.flash.created")
        else
          render :new, status: :unprocessable_entity
        end
      end

      def edit; end

      def update
        if @product.update(product_params)
          redirect_to web_stock_immunobiologic_products_path, notice: t("cidadaobr.stock.products.flash.updated")
        else
          render :edit, status: :unprocessable_entity
        end
      end

      private

      def set_product
        @product = ImmunobiologicProduct.where(municipality_id: current_municipality.id).find(params[:id])
      end

      def product_params
        params.require(:immunobiologic_product).permit(:code, :name, :target_species, :active)
      end
    end
  end
end
