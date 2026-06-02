# frozen_string_literal: true

module Web
  module Stock
    class SupplyItemsController < BaseController
      before_action :require_facility_or_municipality!
      before_action :require_facility_or_municipality_write!, only: %i[new create edit update]
      before_action :set_item, only: %i[edit update]
      before_action :load_simple_items, only: %i[new create edit update]

      def index
        scope = SupplyItem.where(municipality_id: current_municipality.id).order(:name)
        @pagy, @items = pagy(scope.includes(:supply_item_components))
      end

      def new
        @item = SupplyItem.new(active: true, kind: "simple", unit: "unit")
        @component_lines = blank_component_lines
      end

      def create
        @item = SupplyItem.new(item_attributes)
        result = CommandBus.dispatch(
          Inventory::Commands::CreateSupplyItem,
          item: @item,
          municipality: current_municipality,
          components: component_attributes
        )
        @item = result.item
        @component_lines = component_lines_for_form

        if result.success
          redirect_to web_stock_supply_items_path, notice: t("cidadaobr.stock.supply_items.flash.created")
        else
          render :new, status: :unprocessable_entity
        end
      end

      def edit
        @component_lines = existing_component_lines
      end

      def update
        result = CommandBus.dispatch(
          Inventory::Commands::UpdateSupplyItem,
          item: @item,
          attributes: item_attributes,
          components: component_attributes
        )
        @item = result.item
        @component_lines = component_lines_for_form

        if result.success
          redirect_to web_stock_supply_items_path, notice: t("cidadaobr.stock.supply_items.flash.updated")
        else
          render :edit, status: :unprocessable_entity
        end
      end

      private

      def set_item
        @item = SupplyItem.where(municipality_id: current_municipality.id).find(params[:id])
      end

      def load_simple_items
        base = SupplyItem.where(municipality_id: current_municipality.id, kind: "simple")
        linked_ids = linked_component_item_ids

        @simple_items = if linked_ids.any?
          base.where(active: true).or(base.where(id: linked_ids)).order(:name)
        else
          base.where(active: true).order(:name)
        end
      end

      def linked_component_item_ids
        ids = component_attributes.filter_map do |row|
          row.to_h.symbolize_keys[:component_item_id].presence
        end
        ids.concat(@item.supply_item_components.pluck(:component_item_id)) if @item&.persisted?
        ids.uniq
      end

      def supply_item_params
        params.require(:supply_item).permit(
          :category,
          :name,
          :unit,
          :kind,
          :description,
          :sku,
          :active,
          components: [ %i[component_item_id quantity_per_unit] ]
        )
      end

      def item_attributes
        supply_item_params.except(:components)
      end

      def component_attributes
        return [] unless params.key?(:supply_item)

        supply_item_params.fetch(:components, [])
      end

      def existing_component_lines
        lines = @item.supply_item_components.map do |component|
          {
            "component_item_id" => component.component_item_id,
            "quantity_per_unit" => component.quantity_per_unit
          }
        end
        lines.presence || blank_component_lines
      end

      def component_lines_for_form
        lines = component_attributes.map(&:to_h)
        lines.presence || blank_component_lines
      end

      def blank_component_lines
        Array.new(3) { { "component_item_id" => "", "quantity_per_unit" => 1 } }
      end
    end
  end
end
