# frozen_string_literal: true

class CreatePanicAlerts < ActiveRecord::Migration[8.1]
  def change
    create_table :panic_alerts, id: :uuid do |t|
      t.references :municipality, null: false, foreign_key: true, type: :uuid
      t.references :citizen, null: false, foreign_key: true, type: :uuid
      t.references :citizen_account, foreign_key: true, type: :uuid
      t.decimal :latitude, precision: 10, scale: 6
      t.decimal :longitude, precision: 10, scale: 6
      t.string :status, null: false, default: "triggered"
      t.datetime :triggered_at, null: false

      t.timestamps
    end

    add_index :panic_alerts, %i[municipality_id status triggered_at]

    reversible do |dir|
      dir.up { Cidadaobr::TenantRlsPolicies.ensure!(connection: connection) }
    end
  end
end
