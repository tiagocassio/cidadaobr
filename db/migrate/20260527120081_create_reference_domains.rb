# frozen_string_literal: true

class CreateReferenceDomains < ActiveRecord::Migration[8.1]
  def change
    create_table :reference_domains, id: :uuid do |t|
      t.string :domain_key, null: false
      t.string :source, null: false
      t.string :label
      t.timestamps
    end
    add_index :reference_domains, :domain_key, unique: true
  end
end
