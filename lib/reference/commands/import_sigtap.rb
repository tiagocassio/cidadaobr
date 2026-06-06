# frozen_string_literal: true

module Reference
  module Commands
    class ImportSigtap < ApplicationCommand
      def initialize(competence: Date.current.strftime("%Y%m"))
        @competence = competence
      end

      def call
        remote_entries = SigtapRemoteFetcher.fetch_entries(competence: @competence)
        source_path = remote_entries.present? ? "sigtap_remote:#{@competence}" : Reference::DomainSeedImporter.source_path.to_s

        run = ReferenceImportRun.create!(
          job_name: "Reference::Commands::ImportSigtap",
          status: "running",
          started_at: Time.current,
          source_path: source_path
        )

        write_transaction do
          ReferenceDomain.find_or_create_by!(domain_key: "sigtap_procedure") do |domain|
            domain.source = remote_entries.present? ? "sigtap_remote" : "sigtap"
            domain.label = "Procedimentos SIGTAP"
          end
          imported = if remote_entries.present?
                       import_remote_entries!(remote_entries)
                     else
                       Reference::DomainSeedImporter.call(
                         source: "sigtap",
                         domain_keys: %w[sigtap_procedure],
                         payload_competence: @competence
                       )
                     end
          imported
        end.tap do |imported|
          run.finish!(status: "succeeded", records_imported: imported)
        end
      rescue StandardError => e
        run&.finish!(status: "failed", error_message: e.message)
        raise
      end

      private

      def import_remote_entries!(entries)
        timestamp = Time.current

        ReferenceDomainEntry
          .where(domain_key: "sigtap_procedure")
          .update_all(active: false, updated_at: timestamp)

        imported = 0
        entries.each_slice(500) do |slice|
          rows = slice.map do |entry|
            {
              domain_key: "sigtap_procedure",
              code: entry.code,
              label: entry.label,
              active: true,
              payload_json: { "competence" => entry.competence },
              created_at: timestamp,
              updated_at: timestamp
            }
          end

          ReferenceDomainEntry.upsert_all(rows, unique_by: :index_reference_domain_entries_on_domain_code)
          imported += slice.size
        end

        imported
      end
    end
  end
end
