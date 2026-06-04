# frozen_string_literal: true

class CreateTeamSupplyDispatches < ActiveRecord::Migration[8.1]
  def change
    create_table :team_supply_dispatches, id: :uuid do |t|
      t.uuid :municipality_id, null: false
      t.uuid :health_facility_id, null: false
      t.uuid :care_team_id, null: false
      t.date :dispatch_date, null: false
      t.string :status, null: false, default: "pending"
      t.jsonb :lines_json, null: false, default: []
      t.timestamps
    end

    add_index :team_supply_dispatches, %i[care_team_id dispatch_date],
              unique: true,
              name: "index_team_supply_dispatches_on_team_date"
  end
end
