# frozen_string_literal: true

class AddFieldCampaignRoutingForeignKeys < ActiveRecord::Migration[8.1]
  def change
    add_foreign_key :home_visit_campaigns, :health_facilities
    add_foreign_key :visit_routes, :home_visit_campaigns
    add_foreign_key :visit_routes, :care_teams
    add_foreign_key :visit_route_stops, :visit_routes
    add_foreign_key :visit_route_provisioning, :visit_routes
    add_foreign_key :home_visit_campaign_provisioning, :home_visit_campaigns
    add_foreign_key :team_supply_dispatches, :care_teams
  end
end
