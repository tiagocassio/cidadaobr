# frozen_string_literal: true

class TeamSupplyDispatch < ApplicationRecord
  STATUSES = %w[pending dispatched received closed].freeze

  belongs_to :municipality
  belongs_to :health_facility
  belongs_to :care_team

  validates :dispatch_date, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :dispatch_date, uniqueness: { scope: :care_team_id }
end
