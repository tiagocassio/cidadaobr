# frozen_string_literal: true

class SigtapImportJob < ApplicationJob
  queue_as :default

  def perform(competence: Date.current.strftime("%Y%m"))
    run = ReferenceImportRun.create!(
      job_name: self.class.name,
      status: "running",
      started_at: Time.current,
      source_path: Reference::DomainSeedImporter.source_path.to_s
    )

    ReferenceDomain.find_or_create_by!(domain_key: "sigtap_procedure", source: "sigtap", label: "Procedimentos SIGTAP")
    imported = Reference::DomainSeedImporter.call(
      source: "sigtap:#{competence}",
      domain_keys: %w[sigtap_procedure],
      payload_competence: competence
    )
    run.finish!(status: "succeeded", records_imported: imported)
  rescue StandardError => e
    run&.finish!(status: "failed", error_message: e.message)
    raise
  end
end
