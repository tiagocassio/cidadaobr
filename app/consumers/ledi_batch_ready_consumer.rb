# frozen_string_literal: true

class LediBatchReadyConsumer < ApplicationConsumer
  PEC_STUB_REJECTION_PREFIX = "PEC rejeitou lote:"

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
          pec_result = Ledi::PecSubmissionService.call(batch: batch)
          unless pec_result.accepted
            Ledi::RejectLediBatch.call(
              batch: batch,
              reason: "#{PEC_STUB_REJECTION_PREFIX} #{pec_result.rejection_reason}"
            )
            next
          end

          previous_status = batch.status
          batch.update!(status: "submitted")

          RecordPlatformEvent.call(
            event_type: Cidadaobr::KafkaTopics::LEDI_BATCH_STATUSCHANGED,
            aggregate_type: "LediBatch",
            aggregate_id: batch.id,
            payload: {
              ledi_batch_id: batch.id,
              batch_number: batch.batch_number,
              previous_status: previous_status,
              status: batch.status
            },
            care_team_id: batch.care_team_id
          )
        end

        Rails.logger.info("[Kafka] ledi.batch.ready processed for batch #{batch_id}")
      end
    end
  end
end
