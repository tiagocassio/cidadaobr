# frozen_string_literal: true

class AddExpiresOnIndexToImmunobiologicalLots < ActiveRecord::Migration[8.1]
  def change
    remove_index :immunobiological_lots, :expires_on, if_exists: true
    add_index :immunobiological_lots,
              %i[health_facility_id immunobiological_product_id expires_on],
              name: "index_immunobiological_lots_on_facility_product_expires"
  end
end
