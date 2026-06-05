# frozen_string_literal: true

module Reference
  module Commands
    class SyncLediCatalog < ApplicationCommand
      def call
        run = ReferenceImportRun.create!(
          job_name: "Reference::Commands::SyncLediCatalog",
          status: "running",
          started_at: Time.current,
          source_path: "db/seeds/ledi_catalog.rb"
        )

        imported = write_transaction do
          load Rails.root.join("db/seeds/ledi_catalog.rb")
          LediFieldCatalog.count
        end
        run.finish!(status: "succeeded", records_imported: imported)
        imported
      rescue StandardError => e
        run&.finish!(status: "failed", error_message: e.message)
        raise
      end
    end
  end
end
