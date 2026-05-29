# frozen_string_literal: true

class CreateInventoryAndCampaignTables < ActiveRecord::Migration[8.1]
  def change
    create_table :immunobiologic_products, id: :uuid do |t|
      t.uuid :municipality_id, null: false
      t.string :code, null: false
      t.string :name, null: false
      t.string :target_species, null: false, default: "human"
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :immunobiologic_products, %i[municipality_id code], unique: true, name: "index_immunobiologic_products_on_municipality_code"

    create_table :immunobiologic_lots, id: :uuid do |t|
      t.uuid :municipality_id, null: false
      t.uuid :health_facility_id, null: false
      t.uuid :immunobiologic_product_id, null: false
      t.string :lot_number, null: false
      t.date :expires_on, null: false
      t.string :manufacturer
      t.decimal :quantity_on_hand, precision: 12, scale: 3, null: false, default: 0
      t.timestamps
    end
    add_index :immunobiologic_lots,
              %i[health_facility_id immunobiologic_product_id lot_number],
              unique: true,
              name: "index_immunobiologic_lots_on_facility_product_lot"

    create_table :supply_items, id: :uuid do |t|
      t.uuid :municipality_id, null: false
      t.string :code, null: false
      t.string :name, null: false
      t.string :unit, null: false, default: "unit"
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :supply_items, %i[municipality_id code], unique: true, name: "index_supply_items_on_municipality_code"

    create_table :stock_balances, id: :uuid do |t|
      t.uuid :municipality_id, null: false
      t.uuid :health_facility_id, null: false
      t.uuid :immunobiologic_lot_id
      t.uuid :supply_item_id
      t.decimal :quantity, precision: 12, scale: 3, null: false, default: 0
      t.timestamps
    end
    add_index :stock_balances,
              %i[health_facility_id immunobiologic_lot_id],
              unique: true,
              where: "immunobiologic_lot_id IS NOT NULL",
              name: "index_stock_balances_on_facility_lot"
    add_index :stock_balances,
              %i[health_facility_id supply_item_id],
              unique: true,
              where: "supply_item_id IS NOT NULL",
              name: "index_stock_balances_on_facility_supply_item"

    create_table :stock_movements, id: :uuid do |t|
      t.uuid :municipality_id, null: false
      t.uuid :health_facility_id, null: false
      t.uuid :immunobiologic_lot_id
      t.uuid :supply_item_id
      t.string :movement_type, null: false
      t.decimal :quantity, precision: 12, scale: 3, null: false
      t.string :reference_type
      t.uuid :reference_id
      t.text :notes
      t.timestamps
    end
    add_index :stock_movements, %i[municipality_id health_facility_id created_at], name: "index_stock_movements_on_municipality_facility_created"

    create_table :vaccination_campaigns, id: :uuid do |t|
      t.uuid :municipality_id, null: false
      t.uuid :health_facility_id, null: false
      t.uuid :immunobiologic_product_id, null: false
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

    create_table :supply_provisionings, id: :uuid do |t|
      t.uuid :municipality_id, null: false
      t.uuid :health_facility_id, null: false
      t.string :provisionable_type, null: false
      t.uuid :provisionable_id, null: false
      t.string :status, null: false, default: "pending"
      t.jsonb :required_items, null: false, default: []
      t.jsonb :available_items, null: false, default: []
      t.jsonb :shortages, null: false, default: []
      t.boolean :capacity_ok, null: false, default: true
      t.text :rejection_reason
      t.timestamps
    end
    add_index :supply_provisionings,
              %i[provisionable_type provisionable_id],
              unique: true,
              name: "index_supply_provisionings_on_provisionable"

    add_foreign_key :immunobiologic_lots, :immunobiologic_products
    add_foreign_key :immunobiologic_lots, :health_facilities
    add_foreign_key :stock_balances, :immunobiologic_lots
    add_foreign_key :stock_balances, :supply_items
    add_foreign_key :stock_balances, :health_facilities
    add_foreign_key :stock_movements, :immunobiologic_lots
    add_foreign_key :stock_movements, :supply_items
    add_foreign_key :stock_movements, :health_facilities
    add_foreign_key :vaccination_campaigns, :immunobiologic_products
    add_foreign_key :vaccination_campaigns, :health_facilities
  end
end
