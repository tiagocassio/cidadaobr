# frozen_string_literal: true

# Loads reference domains from db/seeds/reference/domains.yml until a real UFSC feed is wired.
class UfscReferenceImportJob < ApplicationJob
  queue_as :default

  def perform
    run = ReferenceImportRun.create!(
      job_name: self.class.name,
      status: "running",
      started_at: Time.current,
      source_path: Reference::DomainSeedImporter.source_path.to_s
    )

    imported = Reference::DomainSeedImporter.call(
      source: "reference_seed",
      domain_keys: %w[ciap2 cid10]
    )
    run.finish!(status: "succeeded", records_imported: imported)
  rescue StandardError => e
    run&.finish!(status: "failed", error_message: e.message)
    raise
  end
end
