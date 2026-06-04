# frozen_string_literal: true

module Reference
  module Commands
    class ImportPniCalendar < ApplicationCommand
      def initialize(export_json: true, publish_release: false, job_name: "PniCalendarImportJob")
        @export_json = export_json
        @publish_release = publish_release
        @job_name = job_name
      end

      def call
        run = start_import_run!

        result = CommandBus.dispatch(
          Reference::Commands::SyncPniCalendar,
          export_json: @export_json,
          publish_release: @publish_release
        )
        run.finish!(status: "succeeded", records_imported: result.fetch(:entries))
        result
      rescue StandardError => e
        run&.finish!(status: "failed", error_message: e.message)
        raise
      end

      private

      def start_import_run!
        write_transaction do
          ReferenceImportRun.create!(
            job_name: @job_name,
            status: "running",
            started_at: Time.current,
            source_path: PniCalendarLoader::PNI_DIR.to_s
          )
        end
      end
    end
  end
end
