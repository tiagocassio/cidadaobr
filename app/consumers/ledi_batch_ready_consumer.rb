# frozen_string_literal: true

class LediBatchReadyConsumer < ApplicationConsumer
  def consume
    messages.each do |message|
      process_with_idempotency(message) do |payload|
        batch_id = payload.dig("payload", "ledi_batch_id") || payload["ledi_batch_id"]
        next if batch_id.blank?

        batch = LediBatch.find_by(id: batch_id)
        next unless batch

        tenant = Cidadaobr::TenantContext.current_or_raise!
        if batch.municipality_id != tenant.municipality_id
          Rails.logger.warn("[Kafka] ledi.batch.ready ignored for batch #{batch_id}: municipality mismatch")
          next
        end

        if batch.status == "ready"
          CommandBus.dispatch(Ledi::SubmitPecBatch, batch: batch)
        end

        Rails.logger.info("[Kafka] ledi.batch.ready processed for batch #{batch_id}")
      end
    end
  end
end
