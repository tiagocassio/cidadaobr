# frozen_string_literal: true

require "rails_helper"

RSpec.describe Reference::Commands::ImportSigtap do
  describe "#import_remote_entries!" do
    it "upserts SIGTAP rows in batches" do
      command = described_class.new(competence: "202602")
      entries = Array.new(600) do |index|
        Reference::SigtapRemoteFetcher::Entry.new(
          code: format("%010d", index + 1),
          label: "Procedimento #{index + 1}",
          competence: "202602"
        )
      end

      imported = command.send(:import_remote_entries!, entries)

      expect(imported).to eq(600)
      expect(ReferenceDomainEntry.where(domain_key: "sigtap_procedure", active: true).count).to eq(600)
    end

    it "deactivates stale SIGTAP rows before upserting" do
      command = described_class.new(competence: "202602")
      ReferenceDomainEntry.create!(
        domain_key: "sigtap_procedure",
        code: "0000000001",
        label: "Legacy",
        active: true,
        payload_json: { "competence" => "202601" }
      )
      entries = [
        Reference::SigtapRemoteFetcher::Entry.new(code: "0000000002", label: "New", competence: "202602")
      ]

      command.send(:import_remote_entries!, entries)

      expect(ReferenceDomainEntry.find_by!(code: "0000000001").active).to be(false)
      expect(ReferenceDomainEntry.find_by!(code: "0000000002").active).to be(true)
    end
  end
end
