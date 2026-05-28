# frozen_string_literal: true

class CreateOutboxMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :outbox_messages, id: :uuid do |t|
      t.uuid :domain_event_id, null: false
      t.uuid :municipality_id, null: false
      t.uuid :health_facility_id
      t.string :topic, null: false
      t.string :event_type, null: false
      t.jsonb :payload, null: false, default: {}
      t.string :status, null: false, default: "pending"
      t.datetime :published_at
      t.text :last_error
      t.timestamps
    end

    add_index :outbox_messages, :status
    add_index :outbox_messages, :domain_event_id, unique: true
    add_index :outbox_messages, :municipality_id
  end
end
