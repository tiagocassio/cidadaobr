# frozen_string_literal: true

class CreateSupplyItemComponents < ActiveRecord::Migration[8.1]
  def change
    create_table :supply_item_components, id: :uuid do |t|
      t.uuid :municipality_id, null: false
      t.uuid :composite_item_id, null: false
      t.uuid :component_item_id, null: false
      t.decimal :quantity_per_unit, precision: 12, scale: 3, null: false, default: 1
      t.timestamps
    end
    add_index :supply_item_components,
              %i[composite_item_id component_item_id],
              unique: true,
              name: "index_supply_item_components_on_composite_and_component"
  end
end
