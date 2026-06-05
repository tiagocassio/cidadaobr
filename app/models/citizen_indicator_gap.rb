# frozen_string_literal: true

class CitizenIndicatorGap < ApplicationRecord
  STATUSES = %w[open resolved waived].freeze

  belongs_to :municipality
  belongs_to :citizen
  belongs_to :care_team, optional: true

  validates :municipality_id, :citizen_id, :indicator_code, :status, presence: true
  validates :status, inclusion: { in: STATUSES }
  validate :indicator_code_must_exist_in_catalog
  validate :good_practice_code_must_be_portaria

  private

  # Gaps drive operational follow-up — require an active Portaria row (not merely a known code).
  def indicator_code_must_exist_in_catalog
    return if indicator_code.blank?
    return if IndicatorCatalog.active_portaria?(indicator_code)

    errors.add(:indicator_code, :invalid)
  end

  # Whitelist only — cross-check that good_practice_code belongs to indicator_code waits for multi-BP seed.
  def good_practice_code_must_be_portaria
    return if good_practice_code.blank?
    return if Indicators::Portaria3493.known_good_practice_code?(good_practice_code)

    errors.add(:good_practice_code, :invalid)
  end
end
