# frozen_string_literal: true

class CreateLediFieldCatalogs < ActiveRecord::Migration[8.1]
  def change
    create_table :ledi_field_catalogs, id: :uuid do |t|
      t.string :record_type, null: false
      t.string :field_path, null: false
      t.string :data_type, null: false
      t.boolean :required, null: false, default: false
      t.integer :min_occurs, null: false, default: 0
      t.integer :max_occurs
      t.string :ledi_version, null: false
      t.timestamps
    end

    add_index :ledi_field_catalogs, [ :record_type, :field_path, :ledi_version ], unique: true, name: "index_ledi_field_catalogs_on_type_path_version"
  end
end
