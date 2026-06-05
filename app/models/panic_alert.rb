# frozen_string_literal: true

class PanicAlert < ApplicationRecord
  STATUSES = %w[triggered acknowledged resolved].freeze

  belongs_to :municipality
  belongs_to :citizen
  belongs_to :citizen_account, optional: true

  validates :status, inclusion: { in: STATUSES }
  validates :triggered_at, presence: true
end
