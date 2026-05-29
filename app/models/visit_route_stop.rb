# frozen_string_literal: true

class VisitRouteStop < ApplicationRecord
  STATUSES = %w[pending visited refused skipped].freeze

  belongs_to :municipality
  belongs_to :visit_route
  belongs_to :citizen
  belongs_to :household, optional: true
  belongs_to :campaign_target, optional: true

  validates :stop_order, presence: true, uniqueness: { scope: :visit_route_id }
  validates :status, inclusion: { in: STATUSES }
end
