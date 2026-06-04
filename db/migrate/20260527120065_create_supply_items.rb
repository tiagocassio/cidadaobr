# frozen_string_literal: true

class CreateSupplyItems < ActiveRecord::Migration[8.1]
  def change
    create_table :supply_items, id: :uuid do |t|
      t.uuid :municipality_id, null: false
      t.string :category, null: false, default: "other"
      t.string :name, null: false
      t.string :unit, null: false, default: "unit"
      t.string :kind, null: false, default: "simple"
      t.text :description
      t.string :sku
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :supply_items,
              %i[municipality_id sku],
              unique: true,
              where: "sku IS NOT NULL",
              name: "index_supply_items_on_municipality_sku"
  end
end
