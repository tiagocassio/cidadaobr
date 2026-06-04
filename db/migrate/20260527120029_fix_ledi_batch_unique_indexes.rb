# frozen_string_literal: true

class FixLediBatchUniqueIndexes < ActiveRecord::Migration[8.1]
  def change
    remove_index :ledi_batches, name: "index_ledi_batches_on_municipality_facility_and_batch_number"

    add_index :ledi_batches,
              [ :municipality_id, :batch_number ],
              unique: true,
              where: "health_facility_id IS NULL AND care_team_id IS NULL",
              name: "index_ledi_batches_on_municipality_batch_number"

    add_index :ledi_batches,
              [ :municipality_id, :health_facility_id, :batch_number ],
              unique: true,
              where: "health_facility_id IS NOT NULL",
              name: "index_ledi_batches_on_municipality_facility_batch_number"

    add_index :ledi_batches,
              [ :municipality_id, :care_team_id, :batch_number ],
              unique: true,
              where: "care_team_id IS NOT NULL",
              name: "index_ledi_batches_on_municipality_team_batch_number"
  end
end
