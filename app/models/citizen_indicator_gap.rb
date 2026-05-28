# frozen_string_literal: true

class CitizenIndicatorGap < ApplicationRecord
  STATUSES = %w[open resolved waived].freeze

  belongs_to :municipality
  belongs_to :citizen
  belongs_to :care_team, optional: true

  validates :municipality_id, :citizen_id, :indicator_code, :status, presence: true
  validates :status, inclusion: { in: STATUSES }
  validate :indicator_code_must_exist_in_catalog

  private

  def indicator_code_must_exist_in_catalog
    return if indicator_code.blank?
    return if IndicatorCatalog.exists?(code: indicator_code)

    errors.add(:indicator_code, :invalid)
  end
end
