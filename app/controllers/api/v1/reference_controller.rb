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
          render json: { domains: [], ledi_version: default_ledi_version }
        end
      end

      def domain
        entries = domain_list_scope.limit(domain_limit)
        render json: {
          domain_key: params[:key],
          entries: entries.map { |entry| domain_entry_json(entry) }
        }
      end

      def search
        entries = domain_search_scope.limit(search_limit)
        render json: {
          domain_key: params[:key],
          query: params[:q].to_s.strip,
          entries: entries.map { |entry| domain_entry_json(entry) }
        }
      end

      def ledi_catalog
        version = params[:ledi_version].presence || default_ledi_version
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

      private

      def domain_list_scope
        ReferenceDomainEntry.active.for_domain(params[:key]).order(:code)
      end

      def domain_search_scope
        query = params[:q].to_s.strip
        scope = domain_list_scope
        return scope if query.blank?

        scope.where("code ILIKE :q OR label ILIKE :q", q: "%#{ActiveRecord::Base.sanitize_sql_like(query)}%")
      end

      def default_ledi_version
        ENV.fetch("LEDI_VERSION", Rails.application.config.ledi.fetch(:version))
      end

      def domain_entry_json(entry)
        { code: entry.code, label: entry.label, payload: entry.payload_json }
      end

      def domain_limit
        500
      end

      def search_limit
        20
      end
    end
  end
end
