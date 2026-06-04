# frozen_string_literal: true

module Indicators
  module PniCodeNormalizer
    module_function

    def normalize_code(code)
      digits = code.to_s.gsub(/\D/, "").sub(/\A0+/, "")
      digits.presence || code.to_s.strip
    end

    def normalize_dose_code(code)
      value = code.to_s.strip.upcase
      return value if value.blank?

      value.sub(/\AD/, "")
    end
  end
end
