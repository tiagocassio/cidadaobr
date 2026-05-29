# frozen_string_literal: true

class CreateIndicatorTables < ActiveRecord::Migration[8.1]
  def change
    create_table :indicator_catalogs, id: :uuid do |t|
      t.string :code, null: false
      t.string :name, null: false
      t.string :funding_component, null: false
      t.string :team_kind
      t.string :methodology_version, null: false, default: "3493/2024"
      t.string :periodicity, null: false, default: "quarterly"
      t.integer :display_order, null: false, default: 0
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :indicator_catalogs, :code, unique: true

    create_table :indicator_rules, id: :uuid do |t|
      t.references :indicator_catalog, type: :uuid, null: false, foreign_key: true
      t.string :rule_code, null: false
      t.string :rule_kind, null: false, default: "good_practice"
      t.jsonb :expression, null: false, default: {}
      t.timestamps
    end
    add_index :indicator_rules, %i[indicator_catalog_id rule_code], unique: true, name: "index_indicator_rules_on_catalog_and_code"

    create_table :citizen_indicator_gaps, id: :uuid do |t|
      t.uuid :municipality_id, null: false
      t.uuid :citizen_id, null: false
      t.uuid :care_team_id
      t.string :indicator_code, null: false
      t.string :good_practice_code
      t.date :due_on
      t.string :status, null: false, default: "open"
      t.timestamps
    end
    add_index :citizen_indicator_gaps,
              %i[citizen_id indicator_code good_practice_code],
              name: "index_citizen_indicator_gaps_on_citizen_indicator_bp"
    add_index :citizen_indicator_gaps, %i[municipality_id indicator_code status],
              name: "index_citizen_indicator_gaps_on_municipality_indicator_status"

    create_table :team_indicator_results, id: :uuid do |t|
      t.uuid :municipality_id, null: false
      t.uuid :care_team_id, null: false
      t.string :indicator_code, null: false
      t.string :quadrimester, null: false
      t.decimal :score, precision: 5, scale: 2
      t.string :tier
      t.decimal :projected_transfer, precision: 12, scale: 2
      t.timestamps
    end
    add_index :team_indicator_results,
              %i[care_team_id indicator_code quadrimester],
              unique: true,
              name: "index_team_indicator_results_unique"
  end
end
