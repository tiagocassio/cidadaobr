# frozen_string_literal: true

class HomeVisitCampaign < ApplicationRecord
  STATUSES = %w[draft targets_built routes_generated scheduled active completed cancelled].freeze

  belongs_to :municipality
  belongs_to :health_facility
  has_many :campaign_targets, as: :campaign, dependent: :destroy
  has_many :visit_routes, dependent: :destroy
  has_one :home_visit_campaign_provisioning, dependent: :destroy
  has_many :supply_plans,
           class_name: "HomeVisitCampaignSupplyPlan",
           dependent: :destroy,
           inverse_of: :home_visit_campaign

  accepts_nested_attributes_for :supply_plans,
                                allow_destroy: true,
                                reject_if: :reject_blank_supply_plan?

  validates :name, :starts_on, :ends_on, presence: true
  validates :status, inclusion: { in: STATUSES }
  validate :ends_on_after_starts_on

  def target_audience_definition
    super.presence || {}
  end

  def supply_plan_item_ids
    supply_plans.map(&:supply_item_id)
  end

  def supply_plan_display_lines
    supply_plans.includes(:supply_item).filter_map do |plan|
      item = plan.supply_item
      next unless item

      {
        name: item.name,
        quantity_per_visit: plan.quantity_per_visit,
        unit: item.unit
      }
    end
  end

  private

  def reject_blank_supply_plan?(attributes)
    attributes["supply_item_id"].blank? && attributes[:supply_item_id].blank?
  end

  def ends_on_after_starts_on
    return if starts_on.blank? || ends_on.blank?
    return if ends_on >= starts_on

    errors.add(:ends_on, :must_be_on_or_after_starts_on)
  end
end
