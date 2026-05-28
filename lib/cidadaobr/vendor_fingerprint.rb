# frozen_string_literal: true

module Cidadaobr
  module VendorFingerprint
    module_function

    def verify_ledi!(config)
      expected = config.fetch(:source_content_sha256)
      sync_path = Rails.root.join("vendor/ledi/#{config.fetch(:version)}/SYNC.sha")
      raise "Missing LEDI vendor manifest at #{sync_path}" unless sync_path.exist?

      actual = sync_path.read[/SOURCE_CONTENT_SHA256=(\h+)/, 1]
      raise "Malformed LEDI vendor manifest at #{sync_path}" if actual.blank?
      return if actual == expected

      raise "LEDI vendor fingerprint mismatch: config=#{expected} vendor=#{actual}"
    end
  end
end
