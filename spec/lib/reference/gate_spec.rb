# frozen_string_literal: true

require "rails_helper"

RSpec.describe Reference::Gate do
  it "runs import chain and publishes a valid release" do
    release = described_class.run!(sigtap_competence: "202602")

    expect(release).to be_persisted
    expect(release.manifest_json["domains"]).not_to be_empty
    expect(release.manifest_json["ledi_catalog_fields"]).to be > 0
    expect(release.sigtap_competence).to eq("202602")
    expect(release.checksum).to be_present
  end

  it "is idempotent on second run" do
    first = described_class.run!(sigtap_competence: "202602")
    second = described_class.run!(sigtap_competence: "202602")

    expect(second.id).to eq(first.id)
  end

  it "publish_release! skips domain and sigtap import" do
    described_class.run!(sigtap_competence: "202602")
    domain_imports = 0
    sigtap_imports = 0
    allow(CommandBus).to receive(:dispatch).and_wrap_original do |method, command, **kwargs|
      domain_imports += 1 if command == Reference::Commands::ImportDomains
      sigtap_imports += 1 if command == Reference::Commands::ImportSigtap
      method.call(command, **kwargs)
    end

    release = described_class.publish_release!(sigtap_competence: "202602")

    expect(release).to be_persisted
    expect(domain_imports).to eq(0)
    expect(sigtap_imports).to eq(0)
  end
end
