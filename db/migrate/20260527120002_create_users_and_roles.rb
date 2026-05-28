# frozen_string_literal: true

class CreateUsersAndRoles < ActiveRecord::Migration[8.1]
  def change
    create_table :roles, id: :uuid do |t|
      t.string :name, null: false
      t.string :code, null: false
      t.timestamps
    end

    add_index :roles, :code, unique: true

    create_table :users, id: :uuid do |t|
      t.string :email, null: false
      t.string :password_digest, null: false
      t.string :full_name, null: false
      t.boolean :active, null: false, default: true
      t.timestamps
    end

    add_index :users, :email, unique: true

    create_table :user_roles, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.references :role, null: false, foreign_key: true, type: :uuid
      t.timestamps
    end

    add_index :user_roles, [ :user_id, :role_id ], unique: true

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

    create_table :care_teams, id: :uuid do |t|
      t.references :municipality, null: false, foreign_key: true, type: :uuid
      t.references :health_facility, null: false, foreign_key: true, type: :uuid
      t.string :ine, null: false
      t.string :name, null: false
      t.timestamps
    end

    add_index :care_teams, [ :municipality_id, :ine ], unique: true

    create_table :user_team_assignments, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.references :care_team, null: false, foreign_key: true, type: :uuid
      t.boolean :active, null: false, default: true
      t.timestamps
    end

    add_index :user_team_assignments, [ :user_id, :care_team_id ], unique: true
  end
end
