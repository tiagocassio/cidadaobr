# frozen_string_literal: true

module Ledi
  class SubmitPecBatch < ApplicationCommand
    PEC_STUB_REJECTION_PREFIX = "PEC rejeitou lote:"

    def initialize(batch:)
      @batch = batch
    end

    def call
      tenant = Cidadaobr::TenantContext.current_or_raise!
      if @batch.municipality_id != tenant.municipality_id
        raise ArgumentError, "batch municipality mismatch"
      end

      return @batch unless @batch.status == "ready"

      pec_result = PecSubmissionService.call(batch: @batch)
      unless pec_result.accepted
        CommandBus.dispatch(Ledi::RejectLediBatch, batch: @batch, reason: "#{PEC_STUB_REJECTION_PREFIX} #{pec_result.rejection_reason}")
        return @batch.reload
      end

      write_transaction do
        previous_status = @batch.status
        @batch.update!(status: "submitted")

        RecordPlatformEvent.call(
          event_type: Cidadaobr::KafkaTopics::LEDI_BATCH_STATUSCHANGED,
          aggregate_type: "LediBatch",
          aggregate_id: @batch.id,
          payload: {
            ledi_batch_id: @batch.id,
            batch_number: @batch.batch_number,
            previous_status: previous_status,
            status: @batch.status
          },
          care_team_id: @batch.care_team_id
        )
      end

      @batch.reload
    end
  end
end
