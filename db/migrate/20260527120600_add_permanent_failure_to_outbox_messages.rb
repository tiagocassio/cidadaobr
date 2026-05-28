# frozen_string_literal: true

class AddPermanentFailureToOutboxMessages < ActiveRecord::Migration[8.1]
  PERMANENT_ERRORS = [
    "Outbox payload missing event_id",
    "Outbox payload event_id must match domain_event_id"
  ].freeze

  def change
    add_column :outbox_messages, :permanent_failure, :boolean, null: false, default: false

    reversible do |dir|
      dir.up do
        execute <<~SQL.squish
          UPDATE outbox_messages
          SET permanent_failure = TRUE
          WHERE status = 'failed'
            AND last_error IN (#{PERMANENT_ERRORS.map { |error| connection.quote(error) }.join(", ")})
        SQL
      end
    end
  end
end
