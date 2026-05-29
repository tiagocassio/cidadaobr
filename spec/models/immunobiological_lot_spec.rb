# frozen_string_literal: true

require "rails_helper"

RSpec.describe ImmunobiologicalLot do
  let(:municipality) { create(:municipality) }
  let(:facility) { create(:health_facility, municipality: municipality) }
  let(:product_a) { create(:immunobiological_product, municipality: municipality, code: "PROD-A") }
  let(:product_b) { create(:immunobiological_product, municipality: municipality, code: "PROD-B") }
  let(:membership) { create(:user_municipality_membership, municipality: municipality, scope: "municipality") }

  it "keeps separate stock balances per lot at the same facility" do
    with_tenant(membership) do
      lot_a = create(
        :immunobiological_lot,
        municipality: municipality,
        health_facility: facility,
        immunobiological_product: product_a,
        lot_number: "A-1",
        quantity_on_hand: 10
      )
      lot_b = create(
        :immunobiological_lot,
        municipality: municipality,
        health_facility: facility,
        immunobiological_product: product_b,
        lot_number: "B-1",
        quantity_on_hand: 20
      )

      lot_a.update!(quantity_on_hand: 15)

      balance_a = StockBalance.find_by!(health_facility: facility, immunobiological_lot: lot_a)
      balance_b = StockBalance.find_by!(health_facility: facility, immunobiological_lot: lot_b)
      expect(balance_a.quantity).to eq(15)
      expect(balance_b.quantity).to eq(20)
    end
  end
end
