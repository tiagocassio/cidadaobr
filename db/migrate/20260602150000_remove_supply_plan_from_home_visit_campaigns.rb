# frozen_string_literal: true

class RemoveSupplyPlanFromHomeVisitCampaigns < ActiveRecord::Migration[8.1]
  def change
    remove_column :home_visit_campaigns, :supply_plan, :jsonb, default: [], null: false
  end
end
