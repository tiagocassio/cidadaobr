# frozen_string_literal: true

module Indicators
  class RecalculateForPniRelease < ApplicationCommand
    def initialize(reference_date: Date.current, indicator_codes: %w[C2])
      @reference_date = reference_date
      @indicator_codes = indicator_codes
    end

    def call
      quadrimester = Quadrimester.current(@reference_date)
      enqueued = 0

      Municipality.find_each(batch_size: 100) do |municipality|
        RecalculatePniReleaseJob.perform_later(
          municipality_id: municipality.id,
          reference_date: @reference_date.iso8601,
          indicator_codes: @indicator_codes
        )
        enqueued += 1
      end

      { municipalities_enqueued: enqueued, quadrimester: quadrimester }
    end
  end
end
