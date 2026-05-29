# frozen_string_literal: true

class HomeVisitCampaignProvisioning < ApplicationRecord
  STATUSES = %w[draft calculated blocked reserved closed].freeze

  belongs_to :municipality
  belongs_to :health_facility
  belongs_to :home_visit_campaign

  validates :status, inclusion: { in: STATUSES }
end
