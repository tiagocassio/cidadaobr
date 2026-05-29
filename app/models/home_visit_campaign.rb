# frozen_string_literal: true

class HomeVisitCampaign < ApplicationRecord
  STATUSES = %w[draft targets_built routes_generated scheduled active completed cancelled].freeze

  belongs_to :municipality
  belongs_to :health_facility
  has_many :campaign_targets, as: :campaign, dependent: :destroy
  has_many :visit_routes, dependent: :destroy
  has_one :home_visit_campaign_provisioning, dependent: :destroy

  validates :name, :starts_on, :ends_on, presence: true
  validates :status, inclusion: { in: STATUSES }
  validate :ends_on_after_starts_on

  private

  def ends_on_after_starts_on
    return if starts_on.blank? || ends_on.blank?
    return if ends_on >= starts_on

    errors.add(:ends_on, :must_be_on_or_after_starts_on)
  end
end
