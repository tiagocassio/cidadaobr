# frozen_string_literal: true

class SigtapImportJob < ApplicationJob
  queue_as :default

  def perform(competence: Date.current.strftime("%Y%m"))
    run = ReferenceImportRun.create!(
      job_name: self.class.name,
      status: "running",
      started_at: Time.current,
      source_path: "sigtap:#{competence}"
    )

    ReferenceDomain.find_or_create_by!(domain_key: "sigtap_procedure", source: "sigtap", label: "Procedimentos SIGTAP")
    imported = Reference::DomainSeedImporter.call(source: "sigtap")
    run.finish!(status: "succeeded", records_imported: imported)
  rescue StandardError => e
    run&.finish!(status: "failed", error_message: e.message)
    raise
  end
end
