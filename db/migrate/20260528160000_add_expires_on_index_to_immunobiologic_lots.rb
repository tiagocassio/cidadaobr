# frozen_string_literal: true

class AddExpiresOnIndexToImmunobiologicLots < ActiveRecord::Migration[8.1]
  def change
    remove_index :immunobiologic_lots, :expires_on, if_exists: true
    add_index :immunobiologic_lots,
              %i[health_facility_id immunobiologic_product_id expires_on],
              name: "index_immunobiologic_lots_on_facility_product_expires"
  end
end
