# frozen_string_literal: true

module Indicators
  module Scoring
    module_function

    def tier_for(score)
      value = score.to_f
      case value
      when 85..100 then "excellent"
      when 65...85 then "good"
      when 45...65 then "sufficient"
      else "regular"
      end
    end

    def projected_transfer_stub(score, team_kind: "esf")
      base = team_kind == "esf" ? 12_000.0 : 8_000.0
      (base * (score.to_f / 100.0)).round(2)
    end
  end
end
