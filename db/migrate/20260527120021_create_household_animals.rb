# frozen_string_literal: true

class CreateHouseholdAnimals < ActiveRecord::Migration[8.1]
  def change
    create_table :household_animals, id: :uuid do |t|
      t.references :household, null: false, foreign_key: true, type: :uuid
      t.string :species, null: false
      t.integer :quantity, null: false, default: 1
      t.string :notes
      t.timestamps
    end

    add_index :household_animals, [ :household_id, :species ]
  end
end
