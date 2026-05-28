# frozen_string_literal: true

class CreateCitizenPortalTables < ActiveRecord::Migration[8.1]
  def change
    create_table :citizen_accounts, id: :uuid do |t|
      t.uuid :municipality_id, null: false
      t.uuid :citizen_id, null: false
      t.string :cpf, null: false
      t.string :password_digest, null: false
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :citizen_accounts, %i[municipality_id cpf], unique: true
    add_index :citizen_accounts, :citizen_id, unique: true

    create_table :citizen_immunization_records, id: :uuid do |t|
      t.uuid :municipality_id, null: false
      t.uuid :citizen_id, null: false
      t.string :vaccine_code, null: false
      t.string :vaccine_name, null: false
      t.string :dose_label
      t.date :applied_on
      t.string :lot_number
      t.string :source, null: false, default: "fv_projection"
      t.timestamps
    end
    add_index :citizen_immunization_records, %i[citizen_id vaccine_code dose_label], name: "index_citizen_immunization_on_citizen_vaccine_dose"
  end
end
