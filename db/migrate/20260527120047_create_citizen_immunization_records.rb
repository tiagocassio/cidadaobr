# frozen_string_literal: true

class CreateCitizenImmunizationRecords < ActiveRecord::Migration[8.1]
  def change
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
