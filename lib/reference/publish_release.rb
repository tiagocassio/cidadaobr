# frozen_string_literal: true

module Reference
  class PublishRelease
    class << self
      def call(ledi_version: ENV.fetch("LEDI_VERSION", "6.3.5"), sigtap_competence: nil)
        manifest = build_manifest(ledi_version: ledi_version, sigtap_competence: sigtap_competence)
        checksum = Digest::SHA256.hexdigest(manifest.to_json)
        release_key = [ ledi_version, sigtap_competence, checksum.first(12) ].compact.join(":")

        existing = ReferenceDataRelease.find_by(checksum: checksum)
        return existing if existing

        ReferenceDataRelease.create!(
          release_key: release_key,
          ledi_version: ledi_version,
          sigtap_competence: sigtap_competence,
          checksum: checksum,
          published_at: Time.current,
          manifest_json: manifest
        )
      end

      private

      def build_manifest(ledi_version:, sigtap_competence:)
        {
          ledi_version: ledi_version,
          sigtap_competence: sigtap_competence,
          domains: ReferenceDomain.order(:domain_key).pluck(:domain_key, :source).map do |key, source|
            { key: key, source: source, entries_count: ReferenceDomainEntry.where(domain_key: key).count }
          end,
          ledi_catalog_fields: catalog_field_count(ledi_version: ledi_version),
          published_at: Time.current.iso8601
        }
      end

      def catalog_field_count(ledi_version:)
        return 0 unless LediFieldCatalog.table_exists?

        LediFieldCatalog.where(ledi_version: ledi_version).count
      end
    end
  end
end
