# frozen_string_literal: true

module Api
  module V1
    class ReferenceController < Api::BaseController
      def manifest
        release = ReferenceDataRelease.order(published_at: :desc).first
        if release
          response.set_header("ETag", %("#{release.checksum}"))
          render json: release.manifest_json.merge(release_key: release.release_key, checksum: release.checksum)
        else
          render json: { domains: [], ledi_version: ENV.fetch("LEDI_VERSION", "6.3.5") }
        end
      end

      def domain
        entries = ReferenceDomainEntry.active.for_domain(params[:key]).order(:code).limit(500)
        render json: {
          domain_key: params[:key],
          entries: entries.map { |entry| { code: entry.code, label: entry.label, payload: entry.payload_json } }
        }
      end

      def ledi_catalog
        version = params[:ledi_version].presence || ENV.fetch("LEDI_VERSION", "6.3.5")
        unless LediFieldCatalog.table_exists?
          return render json: { ledi_version: version, fields: [] }
        end

        fields = LediFieldCatalog.where(ledi_version: version).order(:record_type, :field_path)
        render json: {
          ledi_version: version,
          fields: fields.map do |field|
            {
              record_type: field.record_type,
              field_path: field.field_path,
              data_type: field.data_type,
              required: field.required
            }
          end
        }
      end
    end
  end
end
