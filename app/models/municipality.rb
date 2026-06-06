# frozen_string_literal: true

class Municipality < ApplicationRecord
  encrypts :pec_api_token

  has_many :health_facilities, dependent: :restrict_with_error
  has_many :user_municipality_memberships, dependent: :restrict_with_error
  has_many :care_teams, dependent: :restrict_with_error

  validates :name, :state_code, :ibge_code, presence: true
  validates :ibge_code, uniqueness: true
end
