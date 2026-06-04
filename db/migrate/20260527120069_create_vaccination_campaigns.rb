# frozen_string_literal: true

class CreateVaccinationCampaigns < ActiveRecord::Migration[8.1]
  def change
    create_table :vaccination_campaigns, id: :uuid do |t|
      t.uuid :municipality_id, null: false
      t.uuid :health_facility_id, null: false
      t.uuid :immunobiological_product_id, null: false
      t.string :name, null: false
      t.string :campaign_kind, null: false, default: "human_immunization"
      t.string :status, null: false, default: "draft"
      t.date :starts_on, null: false
      t.date :ends_on, null: false
      t.integer :target_doses, null: false, default: 0
      t.integer :room_capacity_per_day, null: false, default: 0
      t.jsonb :target_audience_definition, null: false, default: {}
      t.timestamps
    end
    add_index :vaccination_campaigns, %i[municipality_id health_facility_id status], name: "index_vaccination_campaigns_on_municipality_facility_status"
  end
end
