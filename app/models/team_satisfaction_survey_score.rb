# frozen_string_literal: true

class TeamSatisfactionSurveyScore < ApplicationRecord
  belongs_to :municipality
  belongs_to :care_team

  validates :reference_month, presence: true
  validates :score, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 10 }
  validates :reference_month, uniqueness: { scope: :care_team_id }

  scope :in_quadrimester, lambda { |quadrimester_code|
    range = Indicators::Quadrimester.range_for(quadrimester_code)
    where(reference_month: range)
  }

  def self.score_for_month(care_team:, reference_date:)
    month = reference_date.beginning_of_month.to_date
    find_by(care_team_id: care_team.id, reference_month: month)&.score&.to_f
  end

  def self.best_score_for_team(care_team:, quadrimester:, reference_date:)
    scope = where(care_team_id: care_team.id)
    if quadrimester.present?
      scope = scope.in_quadrimester(quadrimester)
    else
      window_start = reference_date - 6.months
      scope = scope.where(reference_month: window_start..reference_date)
    end
    scope.maximum(:score)&.to_f
  end
end
