# frozen_string_literal: true

class CreateHomeVisitCampaignSupplyPlans < ActiveRecord::Migration[8.1]
  def up
    create_table :home_visit_campaign_supply_plans, id: :uuid do |t|
      t.references :home_visit_campaign, type: :uuid, null: false, foreign_key: true
      t.references :supply_item, type: :uuid, null: false, foreign_key: true
      t.references :municipality, type: :uuid, null: false, foreign_key: true
      t.decimal :quantity_per_visit, precision: 12, scale: 3, null: false
      t.timestamps
    end

    add_index :home_visit_campaign_supply_plans,
              %i[home_visit_campaign_id supply_item_id],
              unique: true,
              name: "idx_campaign_supply_plans_on_campaign_and_item"
  end

  def down
    drop_table :home_visit_campaign_supply_plans, if_exists: true
    drop_table :home_visit_campaign_supply_plan_lines, if_exists: true
  end
end
