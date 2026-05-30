# frozen_string_literal: true

class LediCatalogSyncJob < ApplicationJob
  queue_as :default

  def perform
    run = ReferenceImportRun.create!(
      job_name: self.class.name,
      status: "running",
      started_at: Time.current,
      source_path: "db/seeds/ledi_catalog.rb"
    )

    load Rails.root.join("db/seeds/ledi_catalog.rb")
    imported = LediFieldCatalog.count
    run.finish!(status: "succeeded", records_imported: imported)
  rescue StandardError => e
    run&.finish!(status: "failed", error_message: e.message)
    raise
  end
end
