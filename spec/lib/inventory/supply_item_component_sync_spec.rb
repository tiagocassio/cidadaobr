# frozen_string_literal: true

require "rails_helper"

RSpec.describe Inventory::SupplyItemComponentSync do
  let(:municipality) { create(:municipality) }
  let(:membership) do
    create(:user_municipality_membership, municipality: municipality, scope: "municipality", role_code: "municipal_admin")
  end

  it "rejects duplicate component rows" do
    syringe = create(:supply_item, municipality: municipality, name: "Seringa", category: "syringe")
    kit = SupplyItem.new(
      municipality: municipality,
      name: "Kit",
      category: "visit_kit",
      unit: "kit",
      kind: "composite",
      description: "Kit"
    )

    with_tenant(membership) do
      kit.save!
      sync = described_class.new(item: kit, municipality_id: municipality.id, components: [
        { component_item_id: syringe.id, quantity_per_unit: 1 },
        { component_item_id: syringe.id, quantity_per_unit: 2 }
      ])

      expect(sync.apply!(municipality: municipality)).to be(false)
      expect(kit.errors[:base]).to include(I18n.t("activerecord.errors.models.supply_item.attributes.base.duplicate_component_item"))
    end
  end

  it "rejects non-positive quantity" do
    syringe = create(:supply_item, municipality: municipality, name: "Seringa", category: "syringe")
    kit = SupplyItem.new(
      municipality: municipality,
      name: "Kit",
      category: "visit_kit",
      unit: "kit",
      kind: "composite",
      description: "Kit"
    )

    with_tenant(membership) do
      kit.save!
      sync = described_class.new(item: kit, municipality_id: municipality.id, components: [
        { component_item_id: syringe.id, quantity_per_unit: 0 }
      ])

      expect(sync.apply!(municipality: municipality)).to be(false)
      expect(kit.errors[:base]).to include(I18n.t("activerecord.errors.models.supply_item.attributes.base.invalid_component_quantity"))
    end
  end

  it "rejects blank quantity" do
    syringe = create(:supply_item, municipality: municipality, name: "Seringa", category: "syringe")
    kit = SupplyItem.new(
      municipality: municipality,
      name: "Kit",
      category: "visit_kit",
      unit: "kit",
      kind: "composite",
      description: "Kit"
    )

    with_tenant(membership) do
      kit.save!
      sync = described_class.new(item: kit, municipality_id: municipality.id, components: [
        { component_item_id: syringe.id, quantity_per_unit: "" }
      ])

      expect(sync.apply!(municipality: municipality)).to be(false)
      expect(kit.errors[:base]).to include(I18n.t("activerecord.errors.models.supply_item.attributes.base.component_quantity_required"))
    end
  end

  it "rejects composite items used as components" do
    syringe = create(:supply_item, municipality: municipality, name: "Seringa", category: "syringe")
    nested_kit = create(:supply_item, municipality: municipality, name: "Subkit", category: "visit_kit", kind: "composite")
    kit = SupplyItem.new(
      municipality: municipality,
      name: "Kit",
      category: "visit_kit",
      unit: "kit",
      kind: "composite",
      description: "Kit"
    )

    with_tenant(membership) do
      kit.save!
      sync = described_class.new(item: kit, municipality_id: municipality.id, components: [
        { component_item_id: nested_kit.id, quantity_per_unit: 1 }
      ])

      expect(sync.apply!(municipality: municipality)).to be(false)
      expect(kit.errors[:base]).to include(I18n.t("activerecord.errors.models.supply_item.attributes.base.component_must_be_simple"))
    end
  end
end
