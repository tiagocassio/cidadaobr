# frozen_string_literal: true

module Web
  class ReferenceDomainsController < BaseController
    def search
      scope = ReferenceDomainEntry.active.for_domain(params.require(:domain_key)).order(:code)
      query = params[:q].to_s.strip
      if query.present?
        scope = scope.where("code ILIKE :q OR label ILIKE :q", q: "%#{ActiveRecord::Base.sanitize_sql_like(query)}%")
      end

      entries = scope.limit(20)
      render json: {
        domain_key: params[:domain_key],
        entries: entries.map { |entry| { code: entry.code, label: entry.label } }
      }
    end
  end
end
