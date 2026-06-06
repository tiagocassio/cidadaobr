# frozen_string_literal: true

module Ledi
  class SubmitPecBatch < ApplicationCommand
    PEC_STUB_REJECTION_PREFIX = "PEC rejeitou lote:"
    INCONSISTENT_TRANSPORT_REASON = "inconsistent transport record states after partial PEC submission"

    def initialize(batch:)
      @batch = batch
    end

    def call
      tenant = Cidadaobr::TenantContext.current_or_raise!
      if @batch.municipality_id != tenant.municipality_id
        raise ArgumentError, "batch municipality mismatch"
      end

      preflight = apply_ready_preconditions!
      return preflight if preflight.is_a?(LediBatch)

      pec_result = post_pec_http_unless_redundant!
      return @batch.reload if pec_result == :done
      return pec_result if pec_result.is_a?(LediBatch)

      finalize_pec_http!(pec_result)
    end

    private

    def post_pec_http_unless_redundant!
      outcome = with_batch_pec_advisory_lock do
        recheck = @batch.with_lock do
          @batch.reload
          next @batch if @batch.status == "submitted"
          next :complete if @batch.pec_http_accepted_at.present?
          next @batch unless @batch.status == "ready"

          :post
        end

        case recheck
        when LediBatch then recheck
        when :complete then :complete
        when :post
          pec_result = PecSubmissionService.call(batch: @batch)
          persist_pec_http_accepted! if pec_result.accepted
          pec_result
        end
      end

      case outcome
      when :complete
        dispatch_ready_action(:complete_pec)
        :done
      when LediBatch then outcome
      else outcome
      end
    end

    def with_batch_pec_advisory_lock
      connection = LediBatch.connection
      quoted = connection.quote("ledi:pec:submit:#{@batch.id}")
      acquired = false
      lock_result = connection.select_value("SELECT pg_try_advisory_lock(hashtextextended(#{quoted}, 0))")
      acquired = ActiveModel::Type::Boolean.new.cast(lock_result)
      unless acquired
        raise Ledi::Errors::PecSubmissionInProgressError,
              "PEC HTTP submission already in progress for batch #{@batch.id}"
      end

      yield
    ensure
      connection.execute("SELECT pg_advisory_unlock(hashtextextended(#{quoted}, 0))") if acquired
    end

    def persist_pec_http_accepted!
      @batch.with_lock do
        @batch.reload
        return if @batch.pec_http_accepted_at.present?
        return unless @batch.status == "ready"

        @batch.update_column(:pec_http_accepted_at, Time.current)
      end
    end

    def apply_ready_preconditions!
      action = @batch.with_lock do
        @batch.reload
        next @batch if @batch.status == "submitted"
        next @batch unless @batch.status == "ready"
        next :complete_pec if @batch.pec_http_accepted_at.present?
        next :finalize_submitted if resubmit_without_http?
        next :reject_inconsistent if inconsistent_transport_state?

        :post_pec
      end

      dispatch_ready_action(action)
    end

    def finalize_pec_http!(pec_result)
      @batch.reload
      return @batch if @batch.status == "submitted"
      return @batch unless @batch.status == "ready"

      if @batch.pec_http_accepted_at.present?
        dispatch_ready_action(:complete_pec)
        return @batch.reload
      end

      unless pec_result.accepted
        CommandBus.dispatch(
          Ledi::RejectLediBatch,
          batch: @batch,
          reason: "#{PEC_STUB_REJECTION_PREFIX} #{pec_result.rejection_reason}"
        )
        return @batch.reload
      end

      @batch.reload
      return @batch unless @batch.status == "ready"

      unless @batch.pec_http_accepted_at.present?
        raise Ledi::Errors::InvalidBatchStateError,
              "PEC accepted batch #{@batch.id} but pec_http_accepted_at was not persisted"
      end

      dispatch_ready_action(:complete_pec)
      @batch.reload
    end

    def dispatch_ready_action(action)
      case action
      when :complete_pec
        complete_pec_submission!
      when :finalize_submitted
        finalize_submitted!
      when :reject_inconsistent
        reject_inconsistent_transport_state!
      when :post_pec
        nil
      else
        action
      end
    end

    def resubmit_without_http?
      @batch.transport_records.where(status: "validated").none? &&
        @batch.transport_records.where(status: "sent").exists?
    end

    def inconsistent_transport_state?
      @batch.transport_records.where(status: "validated").exists? &&
        @batch.transport_records.where(status: "sent").exists?
    end

    def reject_inconsistent_transport_state!
      CommandBus.dispatch(
        Ledi::RejectLediBatch,
        batch: @batch,
        reason: "#{PEC_STUB_REJECTION_PREFIX} #{INCONSISTENT_TRANSPORT_REASON}"
      )
      @batch.reload
    end

    def complete_pec_submission!
      mark_batch_submitted!(mark_transport_sent: true)
    end

    def finalize_submitted!
      mark_batch_submitted!(mark_transport_sent: false)
    end

    def mark_batch_submitted!(mark_transport_sent:)
      @batch.with_lock do
        write_transaction do
          @batch.reload
          return @batch if @batch.status == "submitted"

          previous_status = @batch.status
          @batch.update!(status: "submitted")

          if mark_transport_sent
            @batch.transport_records.where(status: %w[validated sent]).update_all(status: "sent", updated_at: Time.current)
          end

          record_batch_status_changed!(previous_status)
        end
      end

      @batch.reload
    end

    def record_batch_status_changed!(previous_status)
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
  end
end
