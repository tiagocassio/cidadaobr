# frozen_string_literal: true

class CitizenContinuousMedication < ApplicationRecord
  belongs_to :municipality
  belongs_to :citizen

  validates :medication_name, presence: true
  validates :municipality_id, :citizen_id, presence: true
end
