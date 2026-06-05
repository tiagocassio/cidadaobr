# frozen_string_literal: true

module Reference
  # CI gate: deterministic import chain → publish → manifest validation.
  class Gate
    class ValidationError < StandardError; end

    DEFAULT_LED_VERSION = Rails.application.config.ledi.fetch(:version).freeze
    DEFAULT_SIGTAP_COMPETENCE = "202602"

    class << self
      def run!(ledi_version: ENV.fetch("LEDI_VERSION", DEFAULT_LED_VERSION), sigtap_competence: DEFAULT_SIGTAP_COMPETENCE)
        CommandBus.dispatch(Commands::ImportDomains, domain_keys: %w[ciap2 cid10])
        CommandBus.dispatch(Commands::ImportSigtap, competence: sigtap_competence)
        publish_release!(ledi_version: ledi_version, sigtap_competence: sigtap_competence)
      end

      # After SigtapImportJob (recurring day 5); skips domain/SIGTAP re-import.
      def publish_release!(ledi_version: ENV.fetch("LEDI_VERSION", DEFAULT_LED_VERSION), sigtap_competence: DEFAULT_SIGTAP_COMPETENCE, sync_catalog: true, sync_pni: true)
        sync_ledi_catalog! if sync_catalog
        sync_pni_calendar! if sync_pni

        release = CommandBus.dispatch(
          Commands::PublishRelease,
          ledi_version: ledi_version,
          sigtap_competence: sigtap_competence
        )

        validate!(release)
        release
      end

      def sync_ledi_catalog!
        return unless LediFieldCatalog.table_exists?

        CommandBus.dispatch(Commands::SyncLediCatalog)
      end

      def sync_pni_calendar!
        return unless PniScheduleEntry.table_exists?

        CommandBus.dispatch(Commands::SyncPniCalendar)
      end

      def validate!(release)
        manifest = release.manifest_json
        raise ValidationError, "manifest domains empty" if manifest.fetch("domains", []).empty?
        raise ValidationError, "checksum missing" if release.checksum.blank?
        raise ValidationError, "sigtap_competence missing" if release.sigtap_competence.blank?

        catalog_count = manifest["ledi_catalog_fields"].to_i
        raise ValidationError, "ledi_catalog_fields must be positive" unless catalog_count.positive?

        true
      end
    end
  end
end
