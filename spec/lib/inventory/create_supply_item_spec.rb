# frozen_string_literal: true

require "rails_helper"

RSpec.describe Inventory::Commands::CreateSupplyItem do
  let(:municipality) { create(:municipality) }
  let(:membership) do
    create(:user_municipality_membership, municipality: municipality, scope: "municipality", role_code: "municipal_admin")
  end

  it "creates a composite item with components" do
    syringe = create(:supply_item, municipality: municipality, name: "Seringa", category: "syringe")

    with_tenant(membership) do
      item = SupplyItem.new(
        name: "Kit visita",
        category: "visit_kit",
        unit: "kit",
        kind: "composite",
        description: "Kit"
      )

      result = described_class.call(
        item: item,
        municipality: municipality,
        components: [ { component_item_id: syringe.id, quantity_per_unit: 2 } ]
      )

      expect(result.success).to be(true)
      expect(result.item.supply_item_components.count).to eq(1)
      expect(result.item.supply_item_components.first.quantity_per_unit).to eq(2)
    end
  end

  it "rejects composite without components" do
    with_tenant(membership) do
      item = SupplyItem.new(
        name: "Kit vazio",
        category: "visit_kit",
        unit: "kit",
        kind: "composite",
        description: "Kit"
      )

      result = described_class.call(item: item, municipality: municipality, components: [])

      expect(result.success).to be(false)
      expect(result.item.errors[:base]).to be_present
    end
  end

  it "rejects duplicate components" do
    syringe = create(:supply_item, municipality: municipality, name: "Seringa", category: "syringe")

    with_tenant(membership) do
      item = SupplyItem.new(
        name: "Kit duplicado",
        category: "visit_kit",
        unit: "kit",
        kind: "composite",
        description: "Kit"
      )

      result = described_class.call(
        item: item,
        municipality: municipality,
        components: [
          { component_item_id: syringe.id, quantity_per_unit: 1 },
          { component_item_id: syringe.id, quantity_per_unit: 2 }
        ]
      )

      expect(result.success).to be(false)
      expect(result.item.errors[:base]).to include(
        I18n.t("activerecord.errors.models.supply_item.attributes.base.duplicate_component_item")
      )
    end
  end

  it "resets the item as new after rolled back create" do
    syringe = create(:supply_item, municipality: municipality, name: "Seringa", category: "syringe")

    with_tenant(membership) do
      item = SupplyItem.new(
        name: "Kit rollback",
        category: "visit_kit",
        unit: "kit",
        kind: "composite",
        description: "Kit"
      )

      result = described_class.call(
        item: item,
        municipality: municipality,
        components: [
          { component_item_id: syringe.id, quantity_per_unit: 1 },
          { component_item_id: syringe.id, quantity_per_unit: 2 }
        ]
      )

      expect(result.success).to be(false)
      expect(result.item).to be_new_record
      expect(result.item.name).to eq("Kit rollback")
      expect(with_tenant(membership) { SupplyItem.where(name: "Kit rollback").count }).to eq(0)
    end
  end
end
