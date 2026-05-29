# frozen_string_literal: true

class VisitRoute < ApplicationRecord
  STATUSES = %w[draft published in_progress completed cancelled].freeze

  belongs_to :municipality
  belongs_to :health_facility
  belongs_to :home_visit_campaign
  belongs_to :care_team
  has_many :visit_route_stops, dependent: :destroy
  has_one :visit_route_provisioning, dependent: :destroy

  validates :route_date, :sequence_number, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :sequence_number, uniqueness: { scope: %i[home_visit_campaign_id care_team_id route_date] }
end
