# frozen_string_literal: true

class CreateStockBalances < ActiveRecord::Migration[8.1]
  def change
    create_table :stock_balances, id: :uuid do |t|
      t.uuid :municipality_id, null: false
      t.uuid :health_facility_id, null: false
      t.uuid :immunobiological_lot_id
      t.uuid :supply_item_id
      t.decimal :quantity, precision: 12, scale: 3, null: false, default: 0
      t.timestamps
    end
    add_index :stock_balances,
              %i[health_facility_id immunobiological_lot_id],
              unique: true,
              where: "immunobiological_lot_id IS NOT NULL",
              name: "index_stock_balances_on_facility_lot"
    add_index :stock_balances,
              %i[health_facility_id supply_item_id],
              unique: true,
              where: "supply_item_id IS NOT NULL",
              name: "index_stock_balances_on_facility_supply_item"
  end
end
