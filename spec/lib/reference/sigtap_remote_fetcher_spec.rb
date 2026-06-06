# frozen_string_literal: true

require "rails_helper"

RSpec.describe Reference::SigtapRemoteFetcher do
  describe ".fetch_entries" do
    it "returns nil when fixture mode is enabled" do
      original = ENV["SIGTAP_USE_FIXTURE"]
      ENV["SIGTAP_USE_FIXTURE"] = "1"

      expect(described_class.fetch_entries(competence: "202602")).to be_nil
    ensure
      ENV["SIGTAP_USE_FIXTURE"] = original
    end

    it "parses tb_procedimento lines from a downloaded archive" do
      allow(described_class).to receive(:use_fixture?).and_return(false)
      allow(described_class).to receive(:download_and_parse).and_return(
        [
          described_class::Entry.new(code: "0301010064", label: "Consulta médica em atenção básica", competence: "202602")
        ]
      )

      entries = described_class.fetch_entries(competence: "202602")

      expect(entries.size).to eq(1)
      expect(entries.first.code).to eq("0301010064")
    end
  end

  describe ".parse_line" do
    it "parses fixed-width SIGTAP procedure rows" do
      line = "0301010064#{'Consulta médica em atenção básica'.ljust(250)}"
      entry = described_class.send(:parse_line, line, "202602")

      expect(entry.code).to eq("0301010064")
      expect(entry.label).to eq("Consulta médica em atenção básica")
    end
  end

  describe ".use_fixture?" do
    it "requires SIGTAP_LIVE to fetch remotely outside test" do
      allow(Rails.env).to receive(:test?).and_return(false)
      original_live = ENV["SIGTAP_LIVE"]
      original_fixture = ENV["SIGTAP_USE_FIXTURE"]
      ENV.delete("SIGTAP_LIVE")
      ENV.delete("SIGTAP_USE_FIXTURE")

      expect(described_class.use_fixture?).to be(true)
    ensure
      ENV["SIGTAP_LIVE"] = original_live
      ENV["SIGTAP_USE_FIXTURE"] = original_fixture
    end
  end
end
