# frozen_string_literal: true

class AddOutboxPublishingTracking < ActiveRecord::Migration[8.1]
  def change
    add_column :outbox_messages, :publishing_claimed_at, :datetime
    add_column :outbox_messages, :kafka_sent_at, :datetime

    add_index :outbox_messages, :publishing_claimed_at,
              where: "status = 'publishing'",
              name: "index_outbox_messages_on_publishing_claimed_at"

    reversible do |dir|
      dir.up do
        execute <<~SQL.squish
          UPDATE outbox_messages
          SET publishing_claimed_at = updated_at
          WHERE status = 'publishing' AND publishing_claimed_at IS NULL
        SQL
      end
    end
  end
end
