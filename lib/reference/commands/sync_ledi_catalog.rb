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

        vendor_fields = 0
        imported = write_transaction do
          vendor_fields = LediCatalogVendorParser.call
          load Rails.root.join("db/seeds/ledi_catalog.rb")
          LediFieldCatalog.count
        end
        run.finish!(status: "succeeded", records_imported: imported)
        Rails.logger.info("[SyncLediCatalog] vendor_fields=#{vendor_fields} catalog_total=#{imported}") if vendor_fields.positive?
        imported
      rescue StandardError => e
        run&.finish!(status: "failed", error_message: e.message)
        raise
      end
    end
  end
end
