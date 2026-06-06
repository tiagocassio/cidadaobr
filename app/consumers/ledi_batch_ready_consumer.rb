# frozen_string_literal: true

class LediBatchReadyConsumer < ApplicationConsumer
  def consume
    messages.each do |message|
      result = process_with_idempotency(message) do |payload|
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
          submit_pec_batch!(batch)
          Rails.logger.info("[Kafka] ledi.batch.ready submitted batch #{batch_id}")
        else
          Rails.logger.info(
            "[Kafka] ledi.batch.ready skipped batch #{batch_id} (status=#{batch.status})"
          )
        end
      end

      next unless result == :duplicate

      event_id = JSON.parse(message.payload).fetch("event_id")
      Rails.logger.info(
        "[Kafka] ledi.batch.ready duplicate envelope skipped (event_id=#{event_id})"
      )
    rescue JSON::ParserError
      Rails.logger.info("[Kafka] ledi.batch.ready duplicate envelope skipped")
    end
  end

  private

  def submit_pec_batch!(batch)
    CommandBus.dispatch(Ledi::SubmitPecBatch, batch: batch)
  rescue Ledi::Errors::PecSubmissionInProgressError => e
    Rails.logger.info(
      "[Kafka] ledi.batch.ready PEC submission in progress for batch #{batch.id}, Karafka will retry: #{e.message}"
    )
    raise
  end
end
