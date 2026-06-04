# frozen_string_literal: true

class AddInventoryForeignKeys < ActiveRecord::Migration[8.1]
  def change
    add_foreign_key :immunobiological_lots, :immunobiological_products
    add_foreign_key :immunobiological_lots, :health_facilities
    add_foreign_key :stock_balances, :immunobiological_lots
    add_foreign_key :stock_balances, :supply_items
    add_foreign_key :stock_balances, :health_facilities
    add_foreign_key :stock_movements, :immunobiological_lots
    add_foreign_key :stock_movements, :supply_items
    add_foreign_key :stock_movements, :health_facilities
    add_foreign_key :supply_item_components, :supply_items, column: :composite_item_id
    add_foreign_key :supply_item_components, :supply_items, column: :component_item_id
    add_foreign_key :supply_item_components, :municipalities
    add_foreign_key :vaccination_campaigns, :immunobiological_products
    add_foreign_key :vaccination_campaigns, :health_facilities
  end
end
