# frozen_string_literal: true

class CreateLediBatches < ActiveRecord::Migration[8.1]
  def change
    create_table :ledi_batches, id: :uuid do |t|
      t.uuid :municipality_id, null: false
      t.bigint :batch_number, null: false
      t.string :ledi_version, null: false
      t.string :status, null: false, default: "draft"
      t.datetime :submitted_at
      t.timestamps
    end

    add_index :ledi_batches, [ :municipality_id, :batch_number ], unique: true, name: "index_ledi_batches_on_municipality_and_batch_number"
    add_index :ledi_batches, :status
  end
end
