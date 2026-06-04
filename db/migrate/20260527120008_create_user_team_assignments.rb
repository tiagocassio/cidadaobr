# frozen_string_literal: true

class CreateUserTeamAssignments < ActiveRecord::Migration[8.1]
  def change
    create_table :user_team_assignments, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.references :care_team, null: false, foreign_key: true, type: :uuid
      t.boolean :active, null: false, default: true
      t.timestamps
    end

    add_index :user_team_assignments, [ :user_id, :care_team_id ], unique: true
  end
end
