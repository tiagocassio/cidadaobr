# frozen_string_literal: true

class UserMunicipalityMembership < ApplicationRecord
  SCOPES = %w[municipality facility team].freeze
  WEB_SCOPES = %w[municipality facility].freeze
  WEB_ROLE_CODES = %w[municipal_admin facility_manager].freeze
  ROLE_CODES = %w[municipal_admin facility_manager community_agent].freeze

  belongs_to :user
  belongs_to :municipality
  belongs_to :health_facility, optional: true

  scope :active, -> { where(active: true) }

  validates :scope, inclusion: { in: SCOPES }
  validates :role_code, presence: true, inclusion: { in: ROLE_CODES }
  validate :health_facility_required_for_facility_scope
  validate :health_facility_belongs_to_municipality
  validate :prevent_municipality_admin_lockout, on: :update

  def last_active_municipal_admin?
    UserMunicipalityMembership
      .where(municipality_id: municipality_id, scope: "municipality", role_code: "municipal_admin", active: true)
      .where.not(id: id)
      .none?
  end

  private

  def prevent_municipality_admin_lockout
    return unless removes_municipal_admin?

    return unless last_active_municipal_admin?

    errors.add(:base, "Não é possível remover o último administrador municipal.")
  end

  def removes_municipal_admin?
    was_admin = scope_in_database == "municipality" &&
      role_code_in_database == "municipal_admin" &&
      active_in_database != false
    will_be_admin = scope == "municipality" && role_code == "municipal_admin" && active != false

    was_admin && !will_be_admin
  end

  def health_facility_belongs_to_municipality
    return if health_facility_id.blank?

    facility = HealthFacility.find_by(id: health_facility_id)
    return if facility&.municipality_id == municipality_id

    errors.add(:health_facility_id, :invalid)
  end

  def health_facility_required_for_facility_scope
    return unless scope == "facility" && health_facility_id.blank?

    errors.add(:health_facility_id, :required_for_facility_scope)
  end
end
