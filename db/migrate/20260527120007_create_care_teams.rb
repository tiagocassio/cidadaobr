# frozen_string_literal: true

class CreateCareTeams < ActiveRecord::Migration[8.1]
  def change
    create_table :care_teams, id: :uuid do |t|
      t.references :municipality, null: false, foreign_key: true, type: :uuid
      t.references :health_facility, null: false, foreign_key: true, type: :uuid
      t.string :ine, null: false
      t.string :name, null: false
      t.timestamps
    end

    add_index :care_teams, [ :municipality_id, :ine ], unique: true
  end
end
