# frozen_string_literal: true

class LediValidationRule < ApplicationRecord
  SEVERITIES = %w[error warning].freeze

  validates :record_type, :rule_code, :expression, :severity, :ledi_version, presence: true
  validates :rule_code, uniqueness: { scope: [ :record_type, :ledi_version ] }
  validates :severity, inclusion: { in: SEVERITIES }
end
