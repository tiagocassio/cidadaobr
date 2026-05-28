# frozen_string_literal: true

class CitizenImmunizationRecord < ApplicationRecord
  belongs_to :municipality
  belongs_to :citizen

  validates :municipality_id, :citizen_id, :vaccine_code, :vaccine_name, presence: true
end
