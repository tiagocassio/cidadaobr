# frozen_string_literal: true

class CareTeam < ApplicationRecord
  belongs_to :municipality
  belongs_to :health_facility
  has_many :user_team_assignments, dependent: :destroy

  validates :name, :ine, presence: true
  validates :ine, uniqueness: { scope: :municipality_id }
end
