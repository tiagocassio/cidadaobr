# frozen_string_literal: true

module Reference
  class DomainSeedImporter
    SEED_PATH = Rails.root.join("db/seeds/reference/domains.yml")

    class << self
      def call(source: "reference_seed")
        entries = load_entries
        imported = 0

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
            end
          end
        end

        imported
      end

      private

      def load_entries
        return [] unless SEED_PATH.exist?

        YAML.load_file(SEED_PATH).fetch("entries", [])
      end
    end
  end
end
