# frozen_string_literal: true

class CreateFieldCampaignRoutingTables < ActiveRecord::Migration[8.1]
  def change
    add_reference :vaccination_campaigns, :consultation_room, type: :uuid, foreign_key: true, null: true

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

    create_table :home_visit_campaign_provisionings, id: :uuid do |t|
      t.uuid :municipality_id, null: false
      t.uuid :health_facility_id, null: false
      t.uuid :home_visit_campaign_id, null: false
      t.string :status, null: false, default: "draft"
      t.jsonb :totals_json, null: false, default: []
      t.timestamps
    end
    add_index :home_visit_campaign_provisionings, :home_visit_campaign_id,
              unique: true,
              name: "index_home_visit_campaign_provisionings_on_campaign"

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

    create_table :visit_route_provisionings, id: :uuid do |t|
      t.uuid :municipality_id, null: false
      t.uuid :health_facility_id, null: false
      t.uuid :visit_route_id, null: false
      t.string :status, null: false, default: "draft"
      t.jsonb :lines_json, null: false, default: []
      t.timestamps
    end
    add_index :visit_route_provisionings, :visit_route_id,
              unique: true,
              name: "index_visit_route_provisionings_on_route"

    create_table :team_supply_dispatches, id: :uuid do |t|
      t.uuid :municipality_id, null: false
      t.uuid :health_facility_id, null: false
      t.uuid :care_team_id, null: false
      t.date :dispatch_date, null: false
      t.string :status, null: false, default: "pending"
      t.jsonb :lines_json, null: false, default: []
      t.timestamps
    end
    add_index :team_supply_dispatches, %i[care_team_id dispatch_date],
              unique: true,
              name: "index_team_supply_dispatches_on_team_date"

    add_foreign_key :home_visit_campaigns, :health_facilities
    add_foreign_key :visit_routes, :home_visit_campaigns
    add_foreign_key :visit_routes, :care_teams
    add_foreign_key :visit_route_stops, :visit_routes
    add_foreign_key :visit_route_provisionings, :visit_routes
    add_foreign_key :home_visit_campaign_provisionings, :home_visit_campaigns
    add_foreign_key :team_supply_dispatches, :care_teams
  end
end
