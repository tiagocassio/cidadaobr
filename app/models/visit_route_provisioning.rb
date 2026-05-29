# frozen_string_literal: true

class VisitRouteProvisioning < ApplicationRecord
  STATUSES = %w[draft calculated reserved dispatched blocked closed].freeze

  belongs_to :municipality
  belongs_to :health_facility
  belongs_to :visit_route

  validates :status, inclusion: { in: STATUSES }
end
