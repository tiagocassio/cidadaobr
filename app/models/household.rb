# frozen_string_literal: true

class Household < ApplicationRecord
  belongs_to :municipality
  belongs_to :health_facility, optional: true
  belongs_to :care_team, optional: true
  belongs_to :clinical_record, optional: true
  has_many :household_members, dependent: :destroy
  has_many :citizens, through: :household_members

  validates :municipality_id, :ibge_code, presence: true
end
