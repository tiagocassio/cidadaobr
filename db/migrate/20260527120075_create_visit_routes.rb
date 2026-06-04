# frozen_string_literal: true

class CreateVisitRoutes < ActiveRecord::Migration[8.1]
  def change
    create_table :visit_routes, id: :uuid do |t|
      t.uuid :municipality_id, null: false
      t.uuid :health_facility_id, null: false
      t.uuid :home_visit_campaign_id, null: false
      t.uuid :care_team_id, null: false
      t.date :route_date, null: false
      t.integer :sequence_number, null: false, default: 1
      t.string :status, null: false, default: "draft"
      t.timestamps
    end
    add_index :visit_routes,
              %i[home_visit_campaign_id care_team_id route_date sequence_number],
              unique: true,
              name: "index_visit_routes_on_campaign_team_date_seq"
  end
end
