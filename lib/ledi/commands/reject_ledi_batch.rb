# frozen_string_literal: true

module Ledi
  class RejectLediBatch < ApplicationCommand
    def initialize(batch:, reason:)
      @batch = batch
      @reason = reason
    end

    def call
      raise ArgumentError, "reason is required" if @reason.blank?
      return @batch if @batch.status == "rejected"

      raise Ledi::Errors::InvalidBatchStateError, "Batch cannot be rejected" unless @batch.status == "ready"

      previous_status = @batch.status

      write_transaction do
        @batch.update!(status: "rejected", rejection_reason: @reason, rejected_at: Time.current)

        RecordPlatformEvent.call(
          event_type: Cidadaobr::KafkaTopics::LEDI_BATCH_STATUSCHANGED,
          aggregate_type: "LediBatch",
          aggregate_id: @batch.id,
          payload: {
            ledi_batch_id: @batch.id,
            batch_number: @batch.batch_number,
            previous_status: previous_status,
            status: @batch.status,
            rejection_reason: @batch.rejection_reason,
            rejected_at: @batch.rejected_at.iso8601
          },
          care_team_id: @batch.care_team_id
        )
      end

      @batch
    end
  end
end
