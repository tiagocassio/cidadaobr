# frozen_string_literal: true

class CreateDomainEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :domain_events, id: :uuid do |t|
      t.uuid :municipality_id, null: false
      t.uuid :health_facility_id
      t.uuid :care_team_id
      t.string :aggregate_type, null: false
      t.uuid :aggregate_id, null: false
      t.string :event_type, null: false
      t.jsonb :payload, null: false, default: {}
      t.jsonb :metadata, null: false, default: {}
      t.datetime :occurred_at, null: false
      t.bigint :version, null: false
      t.timestamps
    end

    add_index :domain_events, [ :aggregate_type, :aggregate_id, :version ], unique: true, name: "index_domain_events_on_aggregate_version"
    add_index :domain_events, :municipality_id
    add_index :domain_events, :event_type
    add_index :domain_events, :occurred_at
  end
end
