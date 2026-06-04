# frozen_string_literal: true

class CreateImmunobiologicalLots < ActiveRecord::Migration[8.1]
  def change
    create_table :immunobiological_lots, id: :uuid do |t|
      t.uuid :municipality_id, null: false
      t.uuid :health_facility_id, null: false
      t.uuid :immunobiological_product_id, null: false
      t.string :lot_number, null: false
      t.date :expires_on, null: false
      t.string :manufacturer
      t.decimal :quantity_on_hand, precision: 12, scale: 3, null: false, default: 0
      t.timestamps
    end
    add_index :immunobiological_lots,
              %i[health_facility_id immunobiological_product_id lot_number],
              unique: true,
              name: "index_immunobiological_lots_on_facility_product_lot"
  end
end
