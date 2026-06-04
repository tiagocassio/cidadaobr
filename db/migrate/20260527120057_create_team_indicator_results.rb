# frozen_string_literal: true

class CreateTeamIndicatorResults < ActiveRecord::Migration[8.1]
  def change
    create_table :team_indicator_results, id: :uuid do |t|
      t.uuid :municipality_id, null: false
      t.uuid :care_team_id, null: false
      t.string :indicator_code, null: false
      t.string :quadrimester, null: false
      t.decimal :score, precision: 5, scale: 2
      t.string :tier
      t.decimal :projected_transfer, precision: 12, scale: 2
      t.jsonb :metadata_json, default: {}, null: false
      t.timestamps
    end
    add_index :team_indicator_results,
              %i[care_team_id indicator_code quadrimester],
              unique: true,
              name: "index_team_indicator_results_unique"
  end
end
