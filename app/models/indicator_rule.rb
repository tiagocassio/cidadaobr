# frozen_string_literal: true

class IndicatorRule < ApplicationRecord
  RULE_KINDS = %w[numerator denominator good_practice].freeze

  belongs_to :indicator_catalog, class_name: "IndicatorCatalog"

  validates :rule_code, :rule_kind, presence: true
  validates :rule_code, uniqueness: { scope: :indicator_catalog_id }
  validates :rule_kind, inclusion: { in: RULE_KINDS }
  validate :expression_must_be_hash

  private

  def expression_must_be_hash
    return if expression.is_a?(Hash)

    errors.add(:expression, :invalid)
  end
end
