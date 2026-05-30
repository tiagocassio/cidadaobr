# frozen_string_literal: true

module Indicators
  module DslV1
    Context = Data.define(:citizen, :care_team, :quadrimester, :reference_date, :cache) do
      def initialize(citizen:, care_team: nil, quadrimester: nil, reference_date: Date.current, cache: nil)
        super(
          citizen: citizen,
          care_team: care_team || citizen.care_team,
          quadrimester: quadrimester || Indicators::Quadrimester.current(reference_date),
          reference_date: reference_date,
          cache: cache || {}
        )
      end

      def quadrimester_range
        Indicators::Quadrimester.range_for(quadrimester)
      end

      def municipality_id
        citizen.municipality_id
      end
    end
  end
end
