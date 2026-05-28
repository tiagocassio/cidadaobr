# frozen_string_literal: true

class CreateMicroAreas < ActiveRecord::Migration[8.1]
  def change
    create_table :micro_areas, id: :uuid do |t|
      t.references :municipality, null: false, foreign_key: true, type: :uuid
      t.references :care_team, null: false, foreign_key: true, type: :uuid
      t.string :code, null: false
      t.string :name, null: false
      t.st_polygon :coverage, geographic: true, srid: 4326
      t.timestamps
    end

    add_index :micro_areas, [ :municipality_id, :code ], unique: true

    create_table :facility_micro_area_coverages, id: :uuid do |t|
      t.references :health_facility, null: false, foreign_key: true, type: :uuid
      t.references :micro_area, null: false, foreign_key: true, type: :uuid
      t.timestamps
    end

    add_index :facility_micro_area_coverages,
              [ :health_facility_id, :micro_area_id ],
              unique: true,
              name: "index_facility_micro_area_coverages_on_facility_and_area"
  end
end
