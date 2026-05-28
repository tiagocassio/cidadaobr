# frozen_string_literal: true

class CreateOperationalProjections < ActiveRecord::Migration[8.1]
  def change
    create_table :citizens, id: :uuid do |t|
      t.uuid :municipality_id, null: false
      t.uuid :health_facility_id
      t.uuid :care_team_id
      t.string :cpf
      t.string :cns
      t.string :full_name
      t.date :birth_date
      t.string :sex
      t.uuid :clinical_record_id
      t.timestamps
    end

    add_index :citizens, [ :municipality_id, :cpf ], unique: true, where: "cpf IS NOT NULL", name: "index_citizens_on_municipality_and_cpf"
    add_index :citizens, [ :municipality_id, :cns ], unique: true, where: "cns IS NOT NULL", name: "index_citizens_on_municipality_and_cns"

    create_table :households, id: :uuid do |t|
      t.uuid :municipality_id, null: false
      t.uuid :health_facility_id
      t.uuid :care_team_id
      t.string :ibge_code, null: false
      t.string :micro_area_code
      t.string :street
      t.string :street_number
      t.string :complement
      t.string :neighborhood
      t.string :postal_code
      t.uuid :clinical_record_id
      t.timestamps
    end

    add_index :households, [ :municipality_id, :clinical_record_id ], unique: true, name: "index_households_on_municipality_and_clinical_record"

    create_table :household_members, id: :uuid do |t|
      t.uuid :household_id, null: false
      t.uuid :citizen_id, null: false
      t.boolean :family_reference, null: false, default: false
      t.timestamps
    end

    add_index :household_members, [ :household_id, :citizen_id ], unique: true, name: "index_household_members_on_household_and_citizen"

    create_table :encounters, id: :uuid do |t|
      t.uuid :municipality_id, null: false
      t.uuid :health_facility_id
      t.uuid :care_team_id
      t.uuid :citizen_id
      t.uuid :clinical_record_id
      t.uuid :clinical_record_item_id
      t.string :record_type, null: false
      t.datetime :encounter_at, null: false
      t.timestamps
    end

    add_index :encounters, [ :municipality_id, :clinical_record_id, :clinical_record_item_id ], unique: true, name: "index_encounters_on_municipality_and_clinical_refs"
  end
end
