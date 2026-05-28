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

  def active_membership_for(municipality_id)
    user_municipality_memberships.active.find_by(municipality_id: municipality_id)
  end

  def team_ids_for(municipality_id)
    user_team_assignments.active.joins(:care_team)
      .where(care_teams: { municipality_id: municipality_id })
      .pluck(:care_team_id)
  end
end
