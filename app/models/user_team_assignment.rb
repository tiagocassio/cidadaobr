# frozen_string_literal: true

class UserTeamAssignment < ApplicationRecord
  belongs_to :user
  belongs_to :care_team

  scope :active, -> { where(active: true) }
end
