# frozen_string_literal: true

class CreateClinicalRecordItems < ActiveRecord::Migration[8.1]
  def change
    create_table :clinical_record_items, id: :uuid do |t|
      t.uuid :clinical_record_id, null: false
      t.integer :sequence, null: false, default: 0
      t.jsonb :payload_json, null: false, default: {}
      t.string :citizen_cpf
      t.string :citizen_cns
      t.timestamps
    end

    add_index :clinical_record_items, [ :clinical_record_id, :sequence ], unique: true, name: "index_clinical_record_items_on_record_and_sequence"
  end
end
