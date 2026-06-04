# frozen_string_literal: true

class CreateHomeVisitCampaigns < ActiveRecord::Migration[8.1]
  def change
    create_table :home_visit_campaigns, id: :uuid do |t|
      t.uuid :municipality_id, null: false
      t.uuid :health_facility_id, null: false
      t.string :name, null: false
      t.string :status, null: false, default: "draft"
      t.date :starts_on, null: false
      t.date :ends_on, null: false
      t.jsonb :target_audience_definition, null: false, default: {}
      t.jsonb :supply_plan, null: false, default: []
      t.decimal :waste_factor, precision: 5, scale: 4, null: false, default: 0
      t.timestamps
    end
    add_index :home_visit_campaigns, %i[municipality_id health_facility_id status],
              name: "index_home_visit_campaigns_on_municipality_facility_status"
  end
end
