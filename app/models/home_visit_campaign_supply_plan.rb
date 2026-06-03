# frozen_string_literal: true

class HomeVisitCampaignSupplyPlan < ApplicationRecord
  belongs_to :home_visit_campaign
  belongs_to :supply_item
  belongs_to :municipality

  validates :quantity_per_visit, numericality: { greater_than: 0 }
  validates :supply_item_id, uniqueness: { scope: :home_visit_campaign_id }
  validate :supply_item_belongs_to_campaign_municipality

  before_validation :sync_municipality_from_campaign

  private

  def sync_municipality_from_campaign
    self.municipality_id = home_visit_campaign.municipality_id if home_visit_campaign.present?
  end

  def supply_item_belongs_to_campaign_municipality
    return if supply_item.blank? || home_visit_campaign.blank?
    return if supply_item.municipality_id == home_visit_campaign.municipality_id

    errors.add(:supply_item_id, :invalid)
  end
end
