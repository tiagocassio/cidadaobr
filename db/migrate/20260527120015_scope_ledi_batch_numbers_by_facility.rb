# frozen_string_literal: true

class ScopeLediBatchNumbersByFacility < ActiveRecord::Migration[8.1]
  def change
    remove_index :ledi_batches, name: "index_ledi_batches_on_municipality_and_batch_number"
    add_index :ledi_batches,
              [ :municipality_id, :health_facility_id, :batch_number ],
              unique: true,
              name: "index_ledi_batches_on_municipality_facility_and_batch_number"
  end
end
