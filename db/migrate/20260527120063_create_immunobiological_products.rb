# frozen_string_literal: true

class CreateImmunobiologicalProducts < ActiveRecord::Migration[8.1]
  def change
    create_table :immunobiological_products, id: :uuid do |t|
      t.uuid :municipality_id, null: false
      t.string :code, null: false
      t.string :name, null: false
      t.string :target_species, null: false, default: "human"
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :immunobiological_products, %i[municipality_id code], unique: true, name: "index_immunobiological_products_on_municipality_code"
  end
end
