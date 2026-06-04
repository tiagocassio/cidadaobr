# frozen_string_literal: true

class CreateVisitRouteProvisioning < ActiveRecord::Migration[8.1]
  def change
    create_table :visit_route_provisioning, id: :uuid do |t|
      t.uuid :municipality_id, null: false
      t.uuid :health_facility_id, null: false
      t.uuid :visit_route_id, null: false
      t.string :status, null: false, default: "draft"
      t.jsonb :lines_json, null: false, default: []
      t.timestamps
    end
    add_index :visit_route_provisioning, :visit_route_id,
              unique: true,
              name: "index_visit_route_provisioning_on_route"
  end
end
