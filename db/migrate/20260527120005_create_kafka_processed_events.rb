# frozen_string_literal: true

class CreateKafkaProcessedEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :kafka_processed_events, id: :uuid do |t|
      t.uuid :event_id, null: false
      t.string :topic, null: false
      t.string :consumer_group, null: false
      t.datetime :processed_at, null: false
      t.timestamps
    end

    add_index :kafka_processed_events,
              [ :event_id, :topic, :consumer_group ],
              unique: true,
              name: "index_kafka_processed_events_on_idempotency"
  end
end
