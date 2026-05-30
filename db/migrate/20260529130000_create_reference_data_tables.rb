# frozen_string_literal: true

class CreateReferenceDataTables < ActiveRecord::Migration[8.1]
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

    create_table :reference_domains, id: :uuid do |t|
      t.string :domain_key, null: false
      t.string :source, null: false
      t.string :label
      t.timestamps
    end
    add_index :reference_domains, :domain_key, unique: true

    create_table :reference_domain_entries, id: :uuid do |t|
      t.string :domain_key, null: false
      t.string :code, null: false
      t.string :label, null: false
      t.boolean :active, default: true, null: false
      t.jsonb :payload_json, default: {}, null: false
      t.timestamps
    end
    add_index :reference_domain_entries, %i[domain_key code], unique: true, name: "index_reference_domain_entries_on_domain_code"
    add_index :reference_domain_entries, :domain_key

    create_table :reference_import_runs, id: :uuid do |t|
      t.string :job_name, null: false
      t.string :status, null: false, default: "running"
      t.string :source_path
      t.integer :records_imported, default: 0, null: false
      t.text :error_message
      t.datetime :started_at, null: false
      t.datetime :finished_at
      t.timestamps
    end
    add_index :reference_import_runs, %i[job_name started_at]
  end
end
