# frozen_string_literal: true

module Ledi
  class PecSubmissionService
    Result = Data.define(:accepted, :rejection_reason)

    class << self
      def call(batch:)
        if stub_rejection_enabled? && batch.transport_records.where(status: "validated").none?
          return Result.new(false, "validação XSD simulada (LEDI_PEC_STUB_REJECT)")
        end

        Result.new(true, nil)
      end

      private

      def stub_rejection_enabled?
        if Rails.env.production? && ActiveModel::Type::Boolean.new.cast(ENV["LEDI_PEC_STUB_REJECT"])
          Rails.logger.error("[PEC] LEDI_PEC_STUB_REJECT is set in production and will be ignored")
          return false
        end

        ActiveModel::Type::Boolean.new.cast(ENV["LEDI_PEC_STUB_REJECT"])
      end
    end
  end
end
