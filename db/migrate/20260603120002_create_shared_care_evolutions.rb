# frozen_string_literal: true

class CreateSharedCareEvolutions < ActiveRecord::Migration[8.1]
  def change
    create_table :shared_care_evolutions, id: :uuid do |t|
      t.references :shared_care_case, null: false, foreign_key: true, type: :uuid
      t.references :author_user, foreign_key: { to_table: :users }, type: :uuid
      t.string :status, null: false, default: "documented"
      t.text :evolution_note, null: false

      t.timestamps
    end

    reversible do |dir|
      dir.up { Cidadaobr::TenantRlsPolicies.ensure!(connection: connection) }
    end
  end
end
