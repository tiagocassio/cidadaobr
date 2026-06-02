# frozen_string_literal: true

require "rails_helper"

RSpec.describe Inventory::Commands::UpdateSupplyItem do
  let(:municipality) { create(:municipality) }
  let(:membership) do
    create(:user_municipality_membership, municipality: municipality, scope: "municipality", role_code: "municipal_admin")
  end

  it "rolls back item changes when component sync fails" do
    syringe = create(:supply_item, municipality: municipality, name: "Seringa", category: "syringe")
    kit = with_tenant(membership) do
      item = SupplyItem.create!(
        municipality: municipality,
        category: "visit_kit",
        name: "Kit original",
        unit: "kit",
        kind: "composite",
        description: "Kit"
      )
      SupplyItemComponent.create!(
        municipality: municipality,
        composite_item: item,
        component_item: syringe,
        quantity_per_unit: 1
      )
      item
    end

    with_tenant(membership) do
      result = described_class.call(
        item: kit,
        attributes: { name: "Kit alterado" },
        components: [ { component_item_id: syringe.id, quantity_per_unit: 0 } ]
      )

      expect(result.success).to be(false)
      expect(result.item.name).to eq("Kit alterado")
      expect(result.item.errors[:base]).to include(
        I18n.t("activerecord.errors.models.supply_item.attributes.base.invalid_component_quantity")
      )
      kit.reload
      expect(kit.name).to eq("Kit original")
      expect(kit.supply_item_components.count).to eq(1)
      expect(kit.supply_item_components.first.quantity_per_unit).to eq(1)
    end
  end

  it "keeps validation errors when item update fails" do
    existing = create(:supply_item, municipality: municipality, sku: "SKU-1")
    kit = with_tenant(membership) do
      SupplyItem.create!(
        municipality: municipality,
        category: "syringe",
        name: "Outro item",
        unit: "unit",
        kind: "simple",
        description: "Item"
      )
    end

    with_tenant(membership) do
      result = described_class.call(
        item: kit,
        attributes: { sku: existing.sku },
        components: []
      )

      expect(result.success).to be(false)
      expect(result.item.errors[:sku]).to be_present
    end
  end

  it "removes components when kind changes to simple" do
    syringe = create(:supply_item, municipality: municipality, name: "Seringa", category: "syringe")
    kit = with_tenant(membership) do
      item = SupplyItem.create!(
        municipality: municipality,
        category: "visit_kit",
        name: "Kit",
        unit: "kit",
        kind: "composite",
        description: "Kit"
      )
      SupplyItemComponent.create!(
        municipality: municipality,
        composite_item: item,
        component_item: syringe,
        quantity_per_unit: 1
      )
      item
    end

    with_tenant(membership) do
      result = described_class.call(
        item: kit,
        attributes: { kind: "simple" },
        components: []
      )

      expect(result.success).to be(true)
      kit.reload
      expect(kit.simple?).to be(true)
      expect(kit.supply_item_components.count).to eq(0)
    end
  end
end
