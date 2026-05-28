# frozen_string_literal: true

class UserMunicipalityMembership < ApplicationRecord
  SCOPES = %w[municipality facility team].freeze

  belongs_to :user
  belongs_to :municipality
  belongs_to :health_facility, optional: true

  scope :active, -> { where(active: true) }

  validates :scope, inclusion: { in: SCOPES }
  validates :role_code, presence: true
  validate :health_facility_required_for_facility_scope

  private

  def health_facility_required_for_facility_scope
    return unless scope == "facility" && health_facility_id.blank?

    errors.add(:health_facility_id, :required_for_facility_scope)
  end
end
