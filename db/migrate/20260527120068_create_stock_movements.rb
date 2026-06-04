# frozen_string_literal: true

class CreateStockMovements < ActiveRecord::Migration[8.1]
  def change
    create_table :stock_movements, id: :uuid do |t|
      t.uuid :municipality_id, null: false
      t.uuid :health_facility_id, null: false
      t.uuid :immunobiological_lot_id
      t.uuid :supply_item_id
      t.string :movement_type, null: false
      t.decimal :quantity, precision: 12, scale: 3, null: false
      t.string :reference_type
      t.uuid :reference_id
      t.text :notes
      t.timestamps
    end
    add_index :stock_movements, %i[municipality_id health_facility_id created_at], name: "index_stock_movements_on_municipality_facility_created"
  end
end
