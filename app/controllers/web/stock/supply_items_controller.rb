# frozen_string_literal: true

module Web
  module Stock
    class SupplyItemsController < BaseController
      COMPONENT_ROWS = 3

      before_action :require_facility_or_municipality!
      before_action :require_facility_or_municipality_write!, only: %i[new create edit update]
      before_action :set_item, only: %i[edit update]
      before_action :load_simple_items, only: %i[new create edit update]
      before_action :prepare_component_rows, only: %i[edit]

      def index
        scope = SupplyItem.where(municipality_id: current_municipality.id).order(:name)
        @pagy, @items = pagy(scope.includes(:supply_item_components))
      end

      def new
        @item = SupplyItem.new(active: true, kind: "simple", unit: "unit")
        prepare_component_rows
      end

      def create
        @item = SupplyItem.new(supply_item_scalar_params)
        result = CommandBus.dispatch(
          Inventory::Commands::CreateSupplyItem,
          item: @item,
          municipality: current_municipality,
          components: component_attributes
        )
        @item = result.item
        repopulate_component_form_rows!

        if result.success
          redirect_to web_stock_supply_items_path, notice: t("cidadaobr.stock.supply_items.flash.created")
        else
          render :new, status: :unprocessable_entity
        end
      end

      def edit
      end

      def update
        result = CommandBus.dispatch(
          Inventory::Commands::UpdateSupplyItem,
          item: @item,
          attributes: supply_item_scalar_params,
          components: component_attributes
        )
        @item = result.item
        repopulate_component_form_rows!

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
        ids = component_attributes.filter_map { |row| row[:component_item_id].presence }
        ids.concat(@item.supply_item_components.pluck(:component_item_id)) if @item&.persisted?
        ids.uniq
      end

      def supply_item_scalar_params
        require_permitted(
          :supply_item,
          :category,
          :name,
          :unit,
          :kind,
          :description,
          :sku,
          :active
        )
      end

      def nested_component_attributes
        return [] unless params.key?(:supply_item)

        rows = params.fetch(:supply_item, ActionController::Parameters.new).permit(
          supply_item_components_attributes: [
            :id,
            :component_item_id,
            :quantity_per_unit,
            :_destroy
          ]
        )[:supply_item_components_attributes]
        rows.present? ? rows.values : []
      end

      def component_attributes
        nested_component_attributes.filter_map do |row|
          attrs = row.to_h.symbolize_keys
          next if ActiveModel::Type::Boolean.new.cast(attrs[:_destroy])

          {
            component_item_id: attrs[:component_item_id],
            quantity_per_unit: attrs[:quantity_per_unit]
          }
        end
      end

      def repopulate_component_form_rows!
        return prepare_component_rows unless @item.composite?

        @item.association(:supply_item_components).reset
        nested_component_attributes.each do |row|
          attrs = row.to_h.symbolize_keys
          component = @item.supply_item_components.build(
            component_item_id: attrs[:component_item_id],
            quantity_per_unit: attrs[:quantity_per_unit].presence || 1
          )
          component.mark_for_destruction if ActiveModel::Type::Boolean.new.cast(attrs[:_destroy])
        end
        prepare_component_rows
      end

      def prepare_component_rows
        return unless @item

        while @item.supply_item_components.reject(&:marked_for_destruction?).size < COMPONENT_ROWS
          @item.supply_item_components.build(quantity_per_unit: 1)
        end
      end
    end
  end
end
