# frozen_string_literal: true

module Reference
  module Commands
    class ImportDomains < ApplicationCommand
      def initialize(source: "reference_seed", domain_keys: nil, payload_competence: nil)
        @source = source
        @domain_keys = domain_keys
        @payload_competence = payload_competence
      end

      def call
        write_transaction do
          Reference::DomainSeedImporter.call(
            source: @source,
            domain_keys: @domain_keys,
            payload_competence: @payload_competence
          )
        end
      end
    end
  end
end
