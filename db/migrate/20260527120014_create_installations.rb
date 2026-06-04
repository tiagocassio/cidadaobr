# frozen_string_literal: true

class CreateInstallations < ActiveRecord::Migration[8.1]
  def change
    create_table :installations, id: :uuid do |t|
      t.uuid :municipality_id, null: false
      t.string :counter_key, null: false
      t.uuid :installation_uuid, null: false
      t.string :tax_id, null: false
      t.string :legal_name, null: false
      t.timestamps
    end

    add_index :installations, [ :municipality_id, :installation_uuid ], unique: true, name: "index_installations_on_municipality_and_uuid"
    add_index :installations, [ :municipality_id, :counter_key ], unique: true, name: "index_installations_on_municipality_and_counter_key"
  end
end
