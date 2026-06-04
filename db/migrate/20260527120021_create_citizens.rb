# frozen_string_literal: true

class CreateCitizens < ActiveRecord::Migration[8.1]
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
  end
end
