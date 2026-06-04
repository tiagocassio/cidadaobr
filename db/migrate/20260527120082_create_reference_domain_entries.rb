# frozen_string_literal: true

class CreateReferenceDomainEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :reference_domain_entries, id: :uuid do |t|
      t.string :domain_key, null: false
      t.string :code, null: false
      t.string :label, null: false
      t.boolean :active, default: true, null: false
      t.jsonb :payload_json, default: {}, null: false
      t.timestamps
    end
    add_index :reference_domain_entries, %i[domain_key code], unique: true, name: "index_reference_domain_entries_on_domain_code"
    add_index :reference_domain_entries, :domain_key
  end
end
