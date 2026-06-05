# frozen_string_literal: true

class PublishReferenceReleaseJob < ApplicationJob
  queue_as :default

  SIGTAP_DOMAIN = "sigtap_procedure"
  SYNC_LEDI_CATALOG_JOB = "Reference::Commands::SyncLediCatalog"

  # Scheduled after SigtapImportJob on day 5 (see config/recurring.yml).
  def perform
    sigtap_competence = Date.current.strftime("%Y%m")
    import_sigtap!(sigtap_competence) unless sigtap_imported_for_competence?(sigtap_competence)
    Reference::Gate.publish_release!(
      sigtap_competence: sigtap_competence,
      sync_catalog: !ReferenceImportRun.succeeded_today?(SYNC_LEDI_CATALOG_JOB)
    )
  end

  private

  def import_sigtap!(competence)
    CommandBus.dispatch(Reference::Commands::ImportSigtap, competence: competence)
  end

  def sigtap_imported_for_competence?(competence)
    scope = ReferenceDomainEntry.active.for_domain(SIGTAP_DOMAIN)
    total = scope.count
    return false if total.zero?

    scope.where("payload_json->>'competence' = ?", competence).count == total
  end
end
