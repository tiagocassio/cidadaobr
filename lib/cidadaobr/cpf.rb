# frozen_string_literal: true

module Cidadaobr
  module Cpf
    module_function

    def valid?(value)
      digits = value.to_s.gsub(/\D/, "")
      return false unless digits.length == 11
      return false if digits.chars.uniq.one?

      first_check = checksum_digit(digits, 9, 10)
      return false unless digits[9].to_i == first_check

      second_check = checksum_digit(digits, 10, 11)
      digits[10].to_i == second_check
    end

    def generate(stem)
      base = format("%09d", stem.to_i % 1_000_000_000)
      first_digit = checksum_digit("#{base}0", 9, 10)
      second_digit = checksum_digit("#{base}#{first_digit}0", 10, 11)
      "#{base}#{first_digit}#{second_digit}"
    end

    def checksum_digit(digits, length, weight_start)
      sum = digits[0, length].each_char.with_index.sum do |char, index|
        char.to_i * (weight_start - index)
      end
      remainder = sum % 11
      remainder < 2 ? 0 : 11 - remainder
    end
    private_class_method :checksum_digit
  end
end
