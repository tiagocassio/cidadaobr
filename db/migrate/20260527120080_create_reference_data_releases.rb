# frozen_string_literal: true

class CreateReferenceDataReleases < ActiveRecord::Migration[8.1]
  def change
    create_table :reference_data_releases, id: :uuid do |t|
      t.string :release_key, null: false
      t.string :ledi_version, null: false
      t.string :sigtap_competence
      t.string :checksum, null: false
      t.datetime :published_at, null: false
      t.jsonb :manifest_json, default: {}, null: false
      t.timestamps
    end
    add_index :reference_data_releases, :release_key, unique: true
    add_index :reference_data_releases, :published_at
  end
end
