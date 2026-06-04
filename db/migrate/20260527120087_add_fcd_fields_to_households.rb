# frozen_string_literal: true

class AddFcdFieldsToHouseholds < ActiveRecord::Migration[8.1]
  def change
    change_table :households, bulk: true do |t|
      t.integer :property_type
      t.string :reference_point
      t.boolean :no_street_number, null: false, default: false
      t.boolean :outside_micro_area, null: false, default: false
      t.string :contact_phone
      t.string :residence_phone
      t.jsonb :housing_conditions, null: false, default: {}
      t.boolean :animals_on_premises, null: false, default: false
    end
  end
end
