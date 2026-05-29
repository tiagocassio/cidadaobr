# frozen_string_literal: true

class RenameImmunobiologicToImmunobiological < ActiveRecord::Migration[8.1]
  INDEX_RENAMES = {
    immunobiological_lots: [
      %w[index_immunobiologic_lots_on_facility_product_expires index_immunobiological_lots_on_facility_product_expires],
      %w[index_immunobiologic_lots_on_facility_product_lot index_immunobiological_lots_on_facility_product_lot],
      %w[index_immunobiologic_lots_on_expires_on index_immunobiological_lots_on_expires_on]
    ],
    immunobiological_products: [
      %w[index_immunobiologic_products_on_municipality_code index_immunobiological_products_on_municipality_code]
    ]
  }.freeze

  def up
    return unless table_exists?(:immunobiologic_products)

    rename_table :immunobiologic_products, :immunobiological_products
    rename_table :immunobiologic_lots, :immunobiological_lots

    rename_column :immunobiological_lots, :immunobiologic_product_id, :immunobiological_product_id
    rename_column :stock_balances, :immunobiologic_lot_id, :immunobiological_lot_id
    rename_column :stock_movements, :immunobiologic_lot_id, :immunobiological_lot_id
    rename_column :vaccination_campaigns, :immunobiologic_product_id, :immunobiological_product_id

    INDEX_RENAMES.each do |table, pairs|
      pairs.each { |old_name, new_name| safe_rename_index(table, old_name, new_name) }
    end
  end

  def down
    return unless table_exists?(:immunobiological_products)

    INDEX_RENAMES.each do |table, pairs|
      pairs.each { |old_name, new_name| safe_rename_index(table, new_name, old_name) }
    end

    rename_column :vaccination_campaigns, :immunobiological_product_id, :immunobiologic_product_id
    rename_column :stock_movements, :immunobiological_lot_id, :immunobiologic_lot_id
    rename_column :stock_balances, :immunobiological_lot_id, :immunobiologic_lot_id
    rename_column :immunobiological_lots, :immunobiological_product_id, :immunobiologic_product_id

    rename_table :immunobiological_lots, :immunobiologic_lots
    rename_table :immunobiological_products, :immunobiologic_products
  end

  private

  def safe_rename_index(table, old_name, new_name)
    return unless index_name_exists?(table, old_name)
    return if index_name_exists?(table, new_name)

    rename_index table, old_name, new_name
  end
end
