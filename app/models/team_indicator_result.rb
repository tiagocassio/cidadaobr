# frozen_string_literal: true

class TeamIndicatorResult < ApplicationRecord
  TIERS = %w[excellent good sufficient regular].freeze

  belongs_to :municipality
  belongs_to :care_team

  validates :municipality_id, :care_team_id, :indicator_code, :quadrimester, presence: true
  validates :tier, inclusion: { in: TIERS }, allow_nil: true
  validate :indicator_code_must_exist_in_catalog

  private

  def indicator_code_must_exist_in_catalog
    return if indicator_code.blank?
    return if IndicatorCatalog.exists?(code: indicator_code)

    errors.add(:indicator_code, :invalid)
  end
end
