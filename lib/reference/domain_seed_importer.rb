# frozen_string_literal: true

module Reference
  class DomainSeedImporter
    VENDOR_PATH = Rails.root.join("vendor/reference/domains.yml")
    SEED_PATH = Rails.root.join("db/seeds/reference/domains.yml")

    class << self
      def call(source: "reference_seed", domain_keys: nil, payload_competence: nil)
        entries = load_entries
        entries = entries.select { |row| domain_keys.include?(row["domain_key"]) } if domain_keys.present?
        if payload_competence.present?
          entries = entries.map do |row|
            next row unless row["domain_key"] == "sigtap_procedure"

            row.merge("payload" => row.fetch("payload", {}).merge("competence" => payload_competence))
          end
        end
        imported = 0
        imported_codes_by_domain = Hash.new { |hash, key| hash[key] = [] }

        entries.group_by { |row| row["domain_key"] }.each do |domain_key, rows|
          ReferenceDomain.find_or_initialize_by(domain_key: domain_key).tap do |domain|
            domain.source = source
            domain.label = rows.first["domain_label"] || domain_key
            domain.save!
          end

          rows.each do |row|
            ReferenceDomainEntry.find_or_initialize_by(domain_key: domain_key, code: row["code"]).tap do |entry|
              entry.label = row["label"]
              entry.active = row.fetch("active", true)
              entry.payload_json = row.fetch("payload", {})
              entry.save!
              imported += 1
              imported_codes_by_domain[domain_key] << row["code"]
            end
          end
        end

        deactivate_stale_entries!(imported_codes_by_domain)

        imported
      end

      def source_path
        active_path
      end

      private

      def deactivate_stale_entries!(imported_codes_by_domain)
        imported_codes_by_domain.each do |domain_key, codes|
          next if codes.empty?

          ReferenceDomainEntry
            .where(domain_key: domain_key)
            .where.not(code: codes)
            .update_all(active: false, updated_at: Time.current)
        end
      end

      def active_path
        return SEED_PATH if ActiveModel::Type::Boolean.new.cast(ENV["REFERENCE_USE_DB_SEED"])
        return SEED_PATH if Rails.env.production?
        return VENDOR_PATH if Rails.env.development? && VENDOR_PATH.exist?

        SEED_PATH
      end

      def load_entries
        path = active_path
        return [] unless path.exist?

        YAML.load_file(path).fetch("entries", [])
      end
    end
  end
end
