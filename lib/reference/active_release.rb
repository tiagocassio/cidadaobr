# frozen_string_literal: true

module Reference
  module ActiveRelease
    # Platform-global release (EPIC-12); per-municipality pinning is out of scope for Fase 6.
    module_function

    def current
      ReferenceDataRelease.order(published_at: :desc).first
    end

    def manifest_domain_keys(release = current)
      return [] unless release

      release.manifest_json.fetch("domains", []).filter_map do |row|
        case row
        when String then row
        when Hash then row["key"] || row[:key]
        end
      end
    end

    def valid_code?(domain_key:, code:)
      release = current
      return false unless release && code.present?
      return false unless manifest_domain_keys(release).include?(domain_key)

      scope = ReferenceDomainEntry.active.for_domain(domain_key).where(code: code)
      if domain_key == "sigtap_procedure" && release.sigtap_competence.present?
        scope = scope.where("payload_json->>'competence' = ?", release.sigtap_competence)
      end

      scope.exists?
    end

    def loaded?
      current.present? && manifest_domain_keys.any?
    end
  end
end
