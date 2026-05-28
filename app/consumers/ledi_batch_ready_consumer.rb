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

        if batch.status == "ready" && pec_stub_reject?(batch)
          Ledi::RejectLediBatch.call(
            batch: batch,
            reason: "#{PEC_STUB_REJECTION_PREFIX} validação XSD simulada (EPIC-09 pendente)"
          )
        elsif batch.status == "ready"
          previous_status = batch.status
          batch.update!(status: "submitted")

          RecordPlatformEvent.call(
            event_type: "ledi.batch.status_changed",
            aggregate_type: "LediBatch",
            aggregate_id: batch.id,
            payload: {
              ledi_batch_id: batch.id,
              batch_number: batch.batch_number,
              previous_status: previous_status,
              status: batch.status
            },
            topic: OutboxPublisher::TOPIC_MAPPING.fetch("ledi.batch.status_changed"),
            care_team_id: batch.care_team_id
          )
        end

        Rails.logger.info("[Kafka] ledi.batch.ready processed for batch #{batch_id}")
      end
    end
  end

  private

  def pec_stub_reject?(batch)
    return false unless stub_rejection_enabled?

    batch.transport_records.where(status: "validated").none?
  end

  def stub_rejection_enabled?
    if Rails.env.production? && ActiveModel::Type::Boolean.new.cast(ENV["LEDI_PEC_STUB_REJECT"])
      Rails.logger.error("[Kafka] LEDI_PEC_STUB_REJECT is set in production and will be ignored")
      return false
    end

    ActiveModel::Type::Boolean.new.cast(ENV["LEDI_PEC_STUB_REJECT"])
  end
end
