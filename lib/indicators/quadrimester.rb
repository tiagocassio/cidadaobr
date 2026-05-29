# frozen_string_literal: true

module Indicators
  module Quadrimester
    module_function

    def current(reference_date = Date.current)
      for_date(reference_date)
    end

    def for_date(date)
      year = date.year
      quarter = ((date.month - 1) / 4) + 1
      format("%<year>d-Q%<quarter>d", year: year, quarter: quarter)
    end

    def range_for(code)
      year, quarter = parse!(code)
      start_month = ((quarter - 1) * 4) + 1
      start_date = Date.new(year, start_month, 1)
      end_date = start_date.next_month(4).prev_day
      start_date..end_date
    end

    def parse!(code)
      match = code.to_s.match(/\A(\d{4})-Q([1-4])\z/)
      raise ArgumentError, "Invalid quadrimester code: #{code}" unless match

      [ match[1].to_i, match[2].to_i ]
    end
  end
end
