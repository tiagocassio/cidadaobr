# frozen_string_literal: true

require "rails_helper"

RSpec.describe Reference::PublishRelease do
  before do
    Reference::DomainSeedImporter.call
  end

  it "publishes a manifest release with checksum" do
    release = described_class.call(ledi_version: "6.3.5", sigtap_competence: "202605")

    expect(release).to be_persisted
    expect(release.manifest_json["domains"]).not_to be_empty
    expect(release.checksum).to be_present
  end
end
