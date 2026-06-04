# frozen_string_literal: true

class CreateReferenceImportRuns < ActiveRecord::Migration[8.1]
  def change
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
