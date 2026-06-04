# frozen_string_literal: true

class CreatePlatformOutboxMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :platform_outbox_messages, id: :uuid do |t|
      t.uuid :platform_event_id, null: false
      t.string :topic, null: false
      t.string :event_type, null: false
      t.jsonb :payload, null: false, default: {}
      t.string :status, null: false, default: "pending"
      t.datetime :published_at
      t.text :last_error
      t.datetime :publishing_claimed_at
      t.datetime :kafka_sent_at
      t.integer :publish_attempts, null: false, default: 0
      t.boolean :permanent_failure, null: false, default: false
      t.timestamps
    end

    add_index :platform_outbox_messages, :status
    add_index :platform_outbox_messages, :platform_event_id, unique: true
    add_index :platform_outbox_messages, :publishing_claimed_at,
      where: "status = 'publishing'",
      name: "index_platform_outbox_on_publishing_claimed_at"
    add_index :platform_outbox_messages, %i[status permanent_failure updated_at],
      where: "status = 'failed' AND permanent_failure = false",
      name: "index_platform_outbox_on_retryable_failed"
  end
end
