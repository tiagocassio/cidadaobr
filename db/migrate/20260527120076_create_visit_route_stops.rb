# frozen_string_literal: true

class CreateVisitRouteStops < ActiveRecord::Migration[8.1]
  def change
    create_table :visit_route_stops, id: :uuid do |t|
      t.uuid :municipality_id, null: false
      t.uuid :visit_route_id, null: false
      t.integer :stop_order, null: false
      t.uuid :household_id
      t.uuid :citizen_id, null: false
      t.uuid :campaign_target_id
      t.string :status, null: false, default: "pending"
      t.datetime :visited_at
      t.timestamps
    end
    add_index :visit_route_stops, %i[visit_route_id stop_order],
              unique: true,
              name: "index_visit_route_stops_on_route_order"
  end
end
