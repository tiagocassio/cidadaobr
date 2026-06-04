# frozen_string_literal: true

class CreateLediValidationRules < ActiveRecord::Migration[8.1]
  def change
    create_table :ledi_validation_rules, id: :uuid do |t|
      t.string :record_type, null: false
      t.string :rule_code, null: false
      t.jsonb :expression, null: false, default: {}
      t.string :severity, null: false, default: "error"
      t.string :ledi_version, null: false
      t.timestamps
    end

    add_index :ledi_validation_rules, [ :record_type, :rule_code, :ledi_version ], unique: true, name: "index_ledi_validation_rules_on_type_code_version"
  end
end
