# frozen_string_literal: true

class CreateHouseholdMembers < ActiveRecord::Migration[8.1]
  def change
    create_table :household_members, id: :uuid do |t|
      t.uuid :household_id, null: false
      t.uuid :citizen_id, null: false
      t.boolean :family_reference, null: false, default: false
      t.timestamps
    end

    add_index :household_members, [ :household_id, :citizen_id ], unique: true, name: "index_household_members_on_household_and_citizen"
  end
end
