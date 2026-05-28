# frozen_string_literal: true

class LediReviewFixes < ActiveRecord::Migration[8.1]
  def change
    add_column :clinical_records, :validation_errors, :jsonb, null: false, default: []
    add_column :ledi_batches, :health_facility_id, :uuid
    add_column :ledi_batches, :care_team_id, :uuid
    add_index :ledi_batches, :health_facility_id
    add_index :ledi_batches, :care_team_id

    execute <<~SQL.squish
      ALTER TABLE households
      ADD COLUMN location geography(Point, 4326);
    SQL
  end
end
