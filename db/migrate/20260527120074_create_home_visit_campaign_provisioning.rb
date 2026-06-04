# frozen_string_literal: true

class CreateHomeVisitCampaignProvisioning < ActiveRecord::Migration[8.1]
  def change
    create_table :home_visit_campaign_provisioning, id: :uuid do |t|
      t.uuid :municipality_id, null: false
      t.uuid :health_facility_id, null: false
      t.uuid :home_visit_campaign_id, null: false
      t.string :status, null: false, default: "draft"
      t.jsonb :totals_json, null: false, default: []
      t.timestamps
    end
    add_index :home_visit_campaign_provisioning, :home_visit_campaign_id,
              unique: true,
              name: "index_home_visit_campaign_provisioning_on_campaign"
  end
end
