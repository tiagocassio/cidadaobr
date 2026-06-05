# frozen_string_literal: true

require "rails_helper"

RSpec.describe PublishReferenceReleaseJob, type: :job do
  let(:competence) { Date.current.strftime("%Y%m") }

  before { Reference::DomainSeedImporter.call }

  it "skips ImportSigtap when SIGTAP entries exist for the competence" do
    tag_sigtap_entries_with_competence!(competence)

    expect(CommandBus).not_to receive(:dispatch).with(Reference::Commands::ImportSigtap, any_args)
    expect(Reference::Gate).to receive(:publish_release!).with(
      sigtap_competence: competence,
      sync_catalog: true
    )

    described_class.perform_now
  end

  it "imports SIGTAP when competence entries are missing" do
    clear_sigtap_competence_tags!

    expect(Reference::Gate).to receive(:publish_release!).with(
      sigtap_competence: competence,
      sync_catalog: true
    )

    described_class.perform_now

    scope = ReferenceDomainEntry.active.for_domain(PublishReferenceReleaseJob::SIGTAP_DOMAIN)
    expect(scope.where("payload_json->>'competence' = ?", competence).count).to eq(scope.count)
  end

  it "skips LEDI catalog sync when SyncLediCatalog already succeeded today" do
    tag_sigtap_entries_with_competence!(competence)
    ReferenceImportRun.create!(
      job_name: PublishReferenceReleaseJob::SYNC_LEDI_CATALOG_JOB,
      status: "succeeded",
      started_at: Time.current,
      finished_at: Time.current
    )

    expect(Reference::Gate).to receive(:publish_release!).with(
      sigtap_competence: competence,
      sync_catalog: false
    )

    described_class.perform_now
  end

  def tag_sigtap_entries_with_competence!(competence)
    ReferenceDomainEntry.for_domain(PublishReferenceReleaseJob::SIGTAP_DOMAIN).find_each do |entry|
      entry.update!(payload_json: entry.payload_json.merge("competence" => competence))
    end
  end

  def clear_sigtap_competence_tags!
    ReferenceDomainEntry.for_domain(PublishReferenceReleaseJob::SIGTAP_DOMAIN).find_each do |entry|
      entry.update!(payload_json: entry.payload_json.except("competence"))
    end
  end
end
