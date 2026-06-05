# frozen_string_literal: true

class CreateSharedCareCases < ActiveRecord::Migration[8.1]
  def change
    create_table :shared_care_cases, id: :uuid do |t|
      t.references :municipality, null: false, foreign_key: true, type: :uuid
      t.references :citizen, null: false, foreign_key: true, type: :uuid
      t.references :origin_care_team, foreign_key: { to_table: :care_teams }, type: :uuid
      t.string :status, null: false, default: "open"
      t.string :ciap2_code
      t.string :cid10_code
      t.text :clinical_summary

      t.timestamps
    end

    add_index :shared_care_cases, %i[municipality_id citizen_id status]

    reversible do |dir|
      dir.up { Cidadaobr::TenantRlsPolicies.ensure!(connection: connection) }
    end
  end
end
