# frozen_string_literal: true

class IndicatorCatalog < ApplicationRecord
  self.table_name = "indicator_catalog"

  FUNDING_COMPONENTS = %w[fixed linkage quality implementation zoonoses].freeze
  TEAM_KINDS = %w[municipality esf eap esb emulti].freeze

  has_many :indicator_rules, dependent: :destroy

  validates :code, :name, :funding_component, :methodology_version, :periodicity, presence: true
  validates :code, uniqueness: true
  validates :funding_component, inclusion: { in: FUNDING_COMPONENTS }
  validates :team_kind, inclusion: { in: TEAM_KINDS }, allow_nil: true
end
