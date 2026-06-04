# frozen_string_literal: true

class CreateIndicatorCatalogs < ActiveRecord::Migration[8.1]
  def change
    create_table :indicator_catalogs, id: :uuid do |t|
      t.string :code, null: false
      t.string :name, null: false
      t.string :funding_component, null: false
      t.string :team_kind
      t.string :methodology_version, null: false, default: "3493/2024"
      t.string :periodicity, null: false, default: "quarterly"
      t.integer :display_order, null: false, default: 0
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :indicator_catalogs, :code, unique: true
  end
end
