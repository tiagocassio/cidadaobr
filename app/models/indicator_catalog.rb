# frozen_string_literal: true

class IndicatorCatalog < ApplicationRecord
  self.table_name = "indicator_catalog"

  PORTARIA_3493_CODES = Indicators::Portaria3493::INDICATOR_CODES.dup.freeze

  FUNDING_COMPONENTS = %w[fixed linkage quality implementation zoonoses].freeze
  TEAM_KINDS = %w[municipality esf eap esb emulti].freeze

  has_many :indicator_rules, dependent: :destroy

  scope :portaria, -> { where(code: PORTARIA_3493_CODES) }
  scope :active_portaria, -> { portaria.where(active: true) }

  validates :code, :name, :funding_component, :methodology_version, :periodicity, presence: true
  validates :code, uniqueness: true, inclusion: { in: PORTARIA_3493_CODES }
  validates :funding_component, inclusion: { in: FUNDING_COMPONENTS }
  validates :team_kind, inclusion: { in: TEAM_KINDS }, allow_nil: true

  def self.known_portaria_code?(code)
    Indicators::Portaria3493.known_indicator_code?(code)
  end

  def self.active_portaria?(code)
    active_portaria.exists?(code: code)
  end
end
