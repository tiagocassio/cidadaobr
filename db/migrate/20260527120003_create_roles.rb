# frozen_string_literal: true

class CreateRoles < ActiveRecord::Migration[8.1]
  def change
    create_table :roles, id: :uuid do |t|
      t.string :name, null: false
      t.string :code, null: false
      t.timestamps
    end

    add_index :roles, :code, unique: true
  end
end
