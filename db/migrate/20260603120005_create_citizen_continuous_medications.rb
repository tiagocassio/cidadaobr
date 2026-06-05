# frozen_string_literal: true

class CreateCitizenContinuousMedications < ActiveRecord::Migration[8.1]
  def change
    create_table :citizen_continuous_medications, id: :uuid do |t|
      t.references :municipality, null: false, foreign_key: true, type: :uuid
      t.references :citizen, null: false, foreign_key: true, type: :uuid
      t.string :medication_name, null: false
      t.string :dosage
      t.string :frequency
      t.date :started_on
      t.date :ended_on
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :citizen_continuous_medications, %i[citizen_id active]

    reversible do |dir|
      dir.up { Cidadaobr::TenantRlsPolicies.ensure!(connection: connection) }
    end
  end
end
