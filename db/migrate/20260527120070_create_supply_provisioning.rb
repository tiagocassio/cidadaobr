# frozen_string_literal: true

class CreateSupplyProvisioning < ActiveRecord::Migration[8.1]
  def change
    create_table :supply_provisioning, id: :uuid do |t|
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

    add_index :supply_provisioning,
              %i[provisionable_type provisionable_id],
              unique: true,
              name: "index_supply_provisioning_on_provisionable"
  end
end
