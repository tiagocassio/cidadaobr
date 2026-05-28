# frozen_string_literal: true

class LediBatchReadyConsumer < ApplicationConsumer
  # TODO(EPIC-09 / STORY-01-02 follow-up): PEC HTTP submit when ledi.batch.ready is consumed (see TASK-01-06, backlog EPIC-01).

  def consume
    messages.each do |message|
      process_with_idempotency(message) do |payload|
        batch_id = payload.dig("payload", "ledi_batch_id") || payload["ledi_batch_id"]
        Rails.logger.info("[Kafka] ledi.batch.ready received for batch #{batch_id}")
      end
    end
  end
end
