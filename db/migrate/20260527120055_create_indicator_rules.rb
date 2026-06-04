# frozen_string_literal: true

class CreateIndicatorRules < ActiveRecord::Migration[8.1]
  def change
    create_table :indicator_rules, id: :uuid do |t|
      t.references :indicator_catalog, type: :uuid, null: false, foreign_key: true
      t.string :rule_code, null: false
      t.string :rule_kind, null: false, default: "good_practice"
      t.jsonb :expression, null: false, default: {}
      t.timestamps
    end
    add_index :indicator_rules, %i[indicator_catalog_id rule_code], unique: true, name: "index_indicator_rules_on_catalog_and_code"
  end
end
