# frozen_string_literal: true

module Reference
  module ActiveRelease
    module_function

    def current
      ReferenceDataRelease.order(published_at: :desc).first
    end

    def loaded?
      current.present? && current.manifest_json.fetch("domains", []).any?
    end
  end
end
