# frozen_string_literal: true

module Reference
  module Commands
    class PublishRelease < ApplicationCommand
      def initialize(ledi_version: ENV.fetch("LEDI_VERSION", "6.3.5"), sigtap_competence: nil)
        @ledi_version = ledi_version
        @sigtap_competence = sigtap_competence
      end

      def call
        write_transaction do
          manifest = build_manifest
          checksum = Digest::SHA256.hexdigest(manifest.to_json)
          release_key = [ @ledi_version, @sigtap_competence, checksum.first(12) ].compact.join(":")

          existing = ReferenceDataRelease.find_by(checksum: checksum)
          return existing if existing

          release = ReferenceDataRelease.create!(
            release_key: release_key,
            ledi_version: @ledi_version,
            sigtap_competence: @sigtap_competence,
            checksum: checksum,
            published_at: Time.current,
            manifest_json: manifest
          )

          emit_release_published!(release)
          release
        end
      end

      private

      def emit_release_published!(release)
        RecordGlobalPlatformEvent.call(
          event_type: Cidadaobr::KafkaTopics::REFERENCE_RELEASE_PUBLISHED,
          aggregate_type: release.class.name,
          aggregate_id: release.id,
          payload: {
            release_id: release.id,
            release_key: release.release_key,
            ledi_version: release.ledi_version,
            sigtap_competence: release.sigtap_competence,
            checksum: release.checksum,
            published_at: release.published_at.iso8601,
            manifest: release.manifest_json
          }
        )
      end

      def build_manifest
        {
          ledi_version: @ledi_version,
          sigtap_competence: @sigtap_competence,
          domains: ReferenceDomain.order(:domain_key).pluck(:domain_key, :source).map do |key, source|
            { key: key, source: source, entries_count: ReferenceDomainEntry.where(domain_key: key).count }
          end,
          pni_calendars: pni_calendar_manifest,
          ledi_catalog_fields: catalog_field_count,
          published_at: Time.current.iso8601
        }
      end

      def pni_calendar_manifest
        return [] unless PniScheduleEntry.table_exists?

        PniScheduleEntry
          .active
          .select(
            :calendar_year,
            :age_group,
            :effective_from,
            :effective_until,
            "COUNT(*) AS entries_count"
          )
          .group(:calendar_year, :age_group, :effective_from, :effective_until)
          .order(:calendar_year, :age_group, :effective_from)
          .map do |row|
            {
              year: row.calendar_year,
              age_group: row.age_group,
              effective_from: row.effective_from.iso8601,
              effective_until: row.effective_until&.iso8601,
              entries_count: row.entries_count
            }
          end
      end

      def catalog_field_count
        return 0 unless LediFieldCatalog.table_exists?

        LediFieldCatalog.where(ledi_version: @ledi_version).count
      end
    end
  end
end
