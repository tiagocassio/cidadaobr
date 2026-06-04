# frozen_string_literal: true

class AddTeamKindToCareTeams < ActiveRecord::Migration[8.1]
  def change
    add_column :care_teams, :team_kind, :string
    add_index :care_teams, :team_kind
  end
end
