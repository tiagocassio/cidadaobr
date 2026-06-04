# frozen_string_literal: true

class CreateUserMunicipalityMemberships < ActiveRecord::Migration[8.1]
  def change
    create_table :user_municipality_memberships, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.references :municipality, null: false, foreign_key: true, type: :uuid
      t.references :health_facility, foreign_key: true, type: :uuid
      t.string :scope, null: false
      t.string :role_code, null: false
      t.boolean :active, null: false, default: true
      t.timestamps
    end

    add_index :user_municipality_memberships,
              [ :user_id, :municipality_id, :health_facility_id ],
              unique: true,
              name: "index_memberships_on_user_municipality_facility"
  end
end
