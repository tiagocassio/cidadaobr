# frozen_string_literal: true

class CreatePlatformEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :platform_events, id: :uuid do |t|
      t.string :aggregate_type, null: false
      t.uuid :aggregate_id, null: false
      t.string :event_type, null: false
      t.jsonb :payload, null: false, default: {}
      t.jsonb :metadata, null: false, default: {}
      t.datetime :occurred_at, null: false
      t.bigint :version, null: false
      t.timestamps
    end

    add_index :platform_events, %i[aggregate_type aggregate_id version],
      unique: true,
      name: "index_platform_events_on_aggregate_version"
    add_index :platform_events, :event_type
    add_index :platform_events, :occurred_at
  end
end
