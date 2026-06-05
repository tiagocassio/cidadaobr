# frozen_string_literal: true

class PniScheduleEntry < ApplicationRecord
  AGE_GROUPS = %w[child child_2_9 pregnant adolescent adult elderly].freeze
  STRATEGIES = %w[routine campaign].freeze

  validates :calendar_year, :age_group, :effective_from, :immunobiological_code,
            :immunobiological_name, :dose_code, :max_age_days, presence: true
  validates :age_group, inclusion: { in: AGE_GROUPS }
  validates :strategy, inclusion: { in: STRATEGIES }, allow_nil: true
  validates :min_age_days, numericality: { greater_than_or_equal_to: 0 }
  validate :max_age_not_before_min_age

  scope :active, -> { where(active: true) }

  scope :effective_on, lambda { |date|
    active.where("effective_from <= ?", date).where("effective_until IS NULL OR effective_until >= ?", date)
  }

  scope :for_age_group, ->(age_group) { where(age_group: age_group.to_s) }

  def self.latest_release_key_for(reference_date: Date.current, age_group: "child")
    entry = effective_on(reference_date).for_age_group(age_group).order(calendar_year: :desc, effective_from: :desc).first
    return nil unless entry

    "#{entry.calendar_year}:#{age_group}:#{entry.effective_from.iso8601}"
  end

  private

  def max_age_not_before_min_age
    return if max_age_days.blank? || min_age_days.blank?
    return if max_age_days >= min_age_days

    errors.add(:max_age_days, "must be greater than or equal to min_age_days")
  end
end
