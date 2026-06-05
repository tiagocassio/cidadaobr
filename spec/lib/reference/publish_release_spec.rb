# frozen_string_literal: true

require "rails_helper"

RSpec.describe Reference::PublishRelease do
  let(:ledi_version) { LediSpecHelpers.ledi_version }

  before do
    Reference::DomainSeedImporter.call
  end

  it "publishes a manifest release with checksum" do
    release = described_class.call(ledi_version: ledi_version, sigtap_competence: "202602")

    expect(release).to be_persisted
    expect(release.manifest_json["domains"]).not_to be_empty
    expect(release.checksum).to be_present
    expect(release.manifest_json["published_at"]).to be_present
  end

  it "checksum excludes published_at from manifest_json" do
    release = described_class.call(ledi_version: ledi_version, sigtap_competence: "202610")
    body_without_published_at = release.manifest_json.except("published_at")

    expect(release.checksum).to eq(Digest::SHA256.hexdigest(body_without_published_at.to_json))
  end

  it "returns the existing release when checksum is unchanged" do
    first = described_class.call(ledi_version: ledi_version, sigtap_competence: "202602")
    second = described_class.call(ledi_version: ledi_version, sigtap_competence: "202602")

    expect(second.id).to eq(first.id)
    expect(ReferenceDataRelease.count).to eq(1)
  end

  it "creates platform event and outbox when release is new" do
    expect {
      described_class.call(ledi_version: ledi_version, sigtap_competence: "202607")
    }.to change(ReferenceDataRelease, :count).by(1)
      .and change(PlatformEvent, :count).by(1)
      .and change(PlatformOutboxMessage, :count).by(1)

    event = PlatformEvent.last
    expect(event.event_type).to eq(Cidadaobr::KafkaTopics::REFERENCE_RELEASE_PUBLISHED)
    expect(PlatformOutboxMessage.last.topic).to eq(Cidadaobr::KafkaTopics::REFERENCE_RELEASE_PUBLISHED)
  end

  it "does not emit platform events when checksum is unchanged" do
    described_class.call(ledi_version: ledi_version, sigtap_competence: "202608")

    expect {
      described_class.call(ledi_version: ledi_version, sigtap_competence: "202608")
    }.not_to change(PlatformEvent, :count)
  end
end

RSpec.describe Reference::Commands::PublishRelease do
  let(:ledi_version) { LediSpecHelpers.ledi_version }

  before { Reference::DomainSeedImporter.call }

  it "delegates from the legacy module alias" do
    release = Reference::PublishRelease.call(ledi_version: ledi_version, sigtap_competence: "202606")

    expect(release).to be_persisted
    expect(release.sigtap_competence).to eq("202606")
  end
end
