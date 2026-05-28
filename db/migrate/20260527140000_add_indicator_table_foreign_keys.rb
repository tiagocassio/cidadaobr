# frozen_string_literal: true

class AddIndicatorTableForeignKeys < ActiveRecord::Migration[8.1]
  def change
    add_foreign_key :citizen_indicator_gaps, :municipalities, column: :municipality_id
    add_foreign_key :citizen_indicator_gaps, :citizens, column: :citizen_id
    add_foreign_key :citizen_indicator_gaps, :care_teams, column: :care_team_id

    add_foreign_key :team_indicator_results, :municipalities, column: :municipality_id
    add_foreign_key :team_indicator_results, :care_teams, column: :care_team_id
  end
end
