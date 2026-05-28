# frozen_string_literal: true

class AddPublishAttemptsToOutboxMessages < ActiveRecord::Migration[8.1]
  def change
    add_column :outbox_messages, :publish_attempts, :integer, null: false, default: 0

    add_index :outbox_messages,
              %i[status permanent_failure updated_at],
              where: "status = 'failed' AND permanent_failure = FALSE",
              name: "index_outbox_messages_on_retryable_failed"
  end
end
