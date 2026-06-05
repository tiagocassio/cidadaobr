# frozen_string_literal: true

class SharedCareCase < ApplicationRecord
  STATUSES = %w[open in_progress closed].freeze

  belongs_to :municipality
  belongs_to :citizen
  belongs_to :origin_care_team, class_name: "CareTeam", optional: true
  has_many :shared_care_evolutions, dependent: :destroy

  validates :status, inclusion: { in: STATUSES }
  validates :municipality_id, :citizen_id, presence: true
end
