# frozen_string_literal: true

module Ledi
  class PecSubmissionService
    Result = Data.define(:accepted, :rejection_reason)

    class << self
      def call(batch:)
        if stub_rejection_enabled? && batch.transport_records.where(status: "validated").none?
          return Result.new(false, "validação XSD simulada (LEDI_PEC_STUB_REJECT)")
        end

        if deployed? && pec_url_configured?(batch.municipality) && pec_api_token_for(batch.municipality).blank?
          return Result.new(false, "PEC API token not configured for municipality")
        end

        client = client_for(batch.municipality)
        unless client
          return dev_accept_result(batch)
        end

        response = client.submit_batch(batch: batch)
        Result.new(response.accepted, response.rejection_reason)
      rescue PecClient::Error => e
        Result.new(false, e.message)
      end

      private

      def deployed?
        !(Rails.env.development? || Rails.env.test?)
      end

      def pec_url_configured?(municipality)
        if deployed?
          municipality.pec_base_url.presence
        else
          municipality.pec_base_url.presence || ENV["PEC_BASE_URL"].presence
        end
      end

      def client_for(municipality)
        base_url = pec_url_configured?(municipality)
        return if base_url.blank?

        token = pec_api_token_for(municipality)
        PecClient.new(base_url: base_url, api_token: token)
      end

      def pec_api_token_for(municipality)
        if deployed?
          municipality.pec_api_token.presence
        else
          municipality.pec_api_token.presence || ENV["PEC_API_TOKEN"].presence
        end
      end

      def dev_accept_result(batch)
        if deployed?
          return Result.new(false, "PEC endpoint not configured for municipality")
        end

        if batch.transport_records.where(status: "validated").none?
          return Result.new(false, "batch has no validated transport records")
        end

        Result.new(true, nil)
      end

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
