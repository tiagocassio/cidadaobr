# frozen_string_literal: true

class User < ApplicationRecord
  has_secure_password

  has_many :user_roles, dependent: :destroy
  has_many :roles, through: :user_roles
  has_many :user_municipality_memberships, dependent: :destroy
  has_many :user_team_assignments, dependent: :destroy
  has_many :care_teams, through: :user_team_assignments

  validates :email, :full_name, presence: true
  validates :email, uniqueness: true
  validate :prevent_deactivating_last_municipal_admin, on: :update

  def active_membership_for(municipality_id)
    user_municipality_memberships
      .active
      .where(municipality_id: municipality_id)
      .by_scope_precedence
      .first
  end

  def team_ids_for(municipality_id)
    user_team_assignments.active.joins(:care_team)
      .where(care_teams: { municipality_id: municipality_id })
      .pluck(:care_team_id)
  end

  private

  def prevent_deactivating_last_municipal_admin
    return unless active_changed? && !active

    user_municipality_memberships
      .where(scope: "municipality", role_code: "municipal_admin", active: true)
      .find_each do |membership|
        next unless membership.last_active_municipal_admin?

        errors.add(:base, :cannot_deactivate_last_municipal_admin)
        break
      end
  end
end
