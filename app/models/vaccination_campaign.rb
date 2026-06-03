# frozen_string_literal: true

class VaccinationCampaign < ApplicationRecord
  CAMPAIGN_KINDS = %w[human_immunization animal_zoonoses].freeze
  STATUSES = %w[draft provisioning_approved scheduled active completed cancelled].freeze

  belongs_to :municipality
  belongs_to :health_facility
  belongs_to :immunobiological_product
  belongs_to :consultation_room, optional: true
  has_one :supply_provisioning, as: :provisionable, dependent: :destroy
  has_many :campaign_targets, as: :campaign, dependent: :destroy

  validates :name, :starts_on, :ends_on, presence: true
  validates :campaign_kind, inclusion: { in: CAMPAIGN_KINDS }
  validates :status, inclusion: { in: STATUSES }
  validates :target_doses, :room_capacity_per_day, numericality: { greater_than_or_equal_to: 0 }
  validate :ends_on_after_starts_on

  def target_audience_definition
    super.presence || {}
  end

  private

  def ends_on_after_starts_on
    return if starts_on.blank? || ends_on.blank?
    return if ends_on >= starts_on

    errors.add(:ends_on, :must_be_on_or_after_starts_on)
  end
end
