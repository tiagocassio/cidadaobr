# frozen_string_literal: true

module Reference
  module Commands
    class ImportSigtap < ApplicationCommand
      def initialize(competence: Date.current.strftime("%Y%m"))
        @competence = competence
      end

      def call
        run = ReferenceImportRun.create!(
          job_name: "Reference::Commands::ImportSigtap",
          status: "running",
          started_at: Time.current,
          source_path: Reference::DomainSeedImporter.source_path.to_s
        )

        write_transaction do
          ReferenceDomain.find_or_create_by!(domain_key: "sigtap_procedure") do |domain|
            domain.source = "sigtap"
            domain.label = "Procedimentos SIGTAP"
          end
          Reference::DomainSeedImporter.call(
            source: "sigtap",
            domain_keys: %w[sigtap_procedure],
            payload_competence: @competence
          )
        end.tap do |imported|
          run.finish!(status: "succeeded", records_imported: imported)
        end
      rescue StandardError => e
        run&.finish!(status: "failed", error_message: e.message)
        raise
      end
    end
  end
end
