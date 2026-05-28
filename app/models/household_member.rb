# frozen_string_literal: true

class HouseholdMember < ApplicationRecord
  belongs_to :household
  belongs_to :citizen

  validates :household_id, :citizen_id, presence: true
end
