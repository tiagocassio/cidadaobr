# frozen_string_literal: true

require "rails_helper"

RSpec.describe SupplyItem do
  let(:municipality) { create(:municipality) }
  let(:membership) do
    create(:user_municipality_membership, municipality: municipality, scope: "municipality", role_code: "municipal_admin")
  end

  it "expands composite items into component requirements" do
    with_tenant(membership) do
      syringe = create_supply_item(name: "Seringa", category: "syringe", kind: "simple")
      lancet = create_supply_item(name: "Lanceta", category: "lancet", kind: "simple")
      kit = create_supply_item(name: "Kit visita", category: "visit_kit", kind: "composite")
      SupplyItemComponent.create!(
        municipality: municipality,
        composite_item: kit,
        component_item: syringe,
        quantity_per_unit: 1
      )
      SupplyItemComponent.create!(
        municipality: municipality,
        composite_item: kit,
        component_item: lancet,
        quantity_per_unit: 2
      )

      requirements = kit.leaf_requirements(2)

      expect(requirements.find { |req| req.item.id == syringe.id }.quantity).to eq(2)
      expect(requirements.find { |req| req.item.id == lancet.id }.quantity).to eq(4)
    end
  end

  def create_supply_item(name:, category:, kind:)
    SupplyItem.create!(
      municipality: municipality,
      name: name,
      category: category,
      kind: kind,
      description: name,
      unit: "unit"
    )
  end
end
