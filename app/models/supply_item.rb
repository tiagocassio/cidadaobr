# frozen_string_literal: true

class SupplyItem < ApplicationRecord
  # Insumos básicos de UBS reutilizados em campanhas domiciliares / externas.
  CATEGORIES = %w[
    syringe
    needle
    lancet
    glove
    mask
    cap
    gown
    gauze
    cotton_ball
    alcohol_70
    antiseptic
    test_strip
    rapid_test
    collection_tube
    specimen_container
    cold_chain
    adhesive_tape
    bandage
    oral_rehydration
    condom
    lubricant
    larvicide
    insecticide
    water_treatment
    educational_material
    visit_kit
    medication_aux
    sharps_container
    other
  ].freeze

  KINDS = %w[simple composite].freeze

  belongs_to :municipality
  has_many :stock_balances, dependent: :destroy
  has_many :stock_movements, dependent: :restrict_with_error
  has_many :supply_item_components,
           foreign_key: :composite_item_id,
           inverse_of: :composite_item,
           dependent: :destroy
  has_many :components, through: :supply_item_components, source: :component_item

  validates :category, :name, :unit, :kind, presence: true
  validates :category, inclusion: { in: CATEGORIES }
  validates :kind, inclusion: { in: KINDS }
  validates :sku, uniqueness: { scope: :municipality_id }, allow_blank: true

  scope :syringes, -> { where(category: "syringe") }
  scope :composites, -> { where(kind: "composite") }
  scope :simples, -> { where(kind: "simple") }

  def composite?
    kind == "composite"
  end

  def simple?
    kind == "simple"
  end

  def leaf_requirements(multiplier = 1)
    multiplier = multiplier.to_d
    return [ Requirement.new(item: self, quantity: multiplier) ] unless composite?

    supply_item_components.includes(:component_item).flat_map do |component|
      component.component_item.leaf_requirements(multiplier * component.quantity_per_unit)
    end
  end

  Requirement = Data.define(:item, :quantity) do
    def merge_key
      item.id
    end
  end

  class << self
    def find_for_municipality(municipality_id:, supply_item_id:)
      return if supply_item_id.blank?

      find_by(id: supply_item_id, municipality_id: municipality_id)
    end

    def find_for_municipality!(municipality_id:, supply_item_id:)
      find_by!(id: supply_item_id, municipality_id: municipality_id)
    end
  end
end
