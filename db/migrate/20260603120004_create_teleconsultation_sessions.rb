# frozen_string_literal: true

class CreateTeleconsultationSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :teleconsultation_sessions, id: :uuid do |t|
      t.references :municipality, null: false, foreign_key: true, type: :uuid
      t.references :citizen, null: false, foreign_key: true, type: :uuid
      t.references :appointment, foreign_key: true, type: :uuid
      t.string :status, null: false, default: "scheduled"
      t.string :room_token
      t.datetime :scheduled_at

      t.timestamps
    end

    add_index :teleconsultation_sessions, %i[municipality_id citizen_id status]

    reversible do |dir|
      dir.up { Cidadaobr::TenantRlsPolicies.ensure!(connection: connection) }
    end
  end
end
