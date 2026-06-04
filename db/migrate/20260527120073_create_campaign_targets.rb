# frozen_string_literal: true

class CreateCampaignTargets < ActiveRecord::Migration[8.1]
  def change
    create_table :campaign_targets, id: :uuid do |t|
      t.uuid :municipality_id, null: false
      t.uuid :health_facility_id, null: false
      t.string :campaign_type, null: false
      t.uuid :campaign_id, null: false
      t.uuid :citizen_id, null: false
      t.uuid :household_id
      t.string :status, null: false, default: "pending"
      t.integer :priority_score, null: false, default: 0
      t.timestamps
    end
    add_index :campaign_targets, %i[campaign_type campaign_id citizen_id],
              unique: true,
              name: "index_campaign_targets_on_campaign_citizen"
    add_index :campaign_targets, %i[campaign_type campaign_id status],
              name: "index_campaign_targets_on_campaign_status"
  end
end
