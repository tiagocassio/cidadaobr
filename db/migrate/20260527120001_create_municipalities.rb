# frozen_string_literal: true

class CreateMunicipalities < ActiveRecord::Migration[8.1]
  def change
    create_table :municipalities, id: :uuid do |t|
      t.string :name, null: false
      t.string :ibge_code, null: false
      t.string :state_code, null: false, limit: 2
      t.timestamps
    end

    add_index :municipalities, :ibge_code, unique: true
  end
end
