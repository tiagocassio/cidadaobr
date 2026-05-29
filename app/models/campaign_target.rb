# frozen_string_literal: true

class CampaignTarget < ApplicationRecord
  STATUSES = %w[pending routed visited refused].freeze

  belongs_to :municipality
  belongs_to :health_facility
  belongs_to :citizen
  belongs_to :household, optional: true
  belongs_to :campaign, polymorphic: true

  validates :status, inclusion: { in: STATUSES }
  validates :citizen_id, uniqueness: { scope: %i[campaign_type campaign_id] }
end
