# frozen_string_literal: true

require "rails_helper"

RSpec.describe Reference::Commands::SyncPniCalendar do
  include ActiveSupport::Testing::TimeHelpers

  before do
    Reference::DomainSeedImporter.call
  end

  describe "#call" do
    it "upserts calendar entries idempotently" do
      first = CommandBus.dispatch(described_class, export_json: false, publish_release: false)
      second = CommandBus.dispatch(described_class, export_json: false, publish_release: false)

      expect(first.fetch(:entries)).to be_positive
      expect(second.fetch(:entries)).to eq(first.fetch(:entries))
      expect(PniScheduleEntry.active.count).to eq(Reference::PniCalendarDefinitions.child_0_2_entries.size)
    end

    it "exports JSON audit trail when requested" do
      CommandBus.dispatch(described_class, export_json: true, publish_release: false)

      path = Reference::PniCalendarLoader.export_path_for(Reference::PniCalendarDefinitions.child_0_2_2026)
      expect(path).to exist
      exported = JSON.parse(path.read)
      expect(exported.fetch("entries").size).to eq(Reference::PniCalendarDefinitions.child_0_2_entries.size)
    end

    it "publishes a reference release with PNI manifest metadata" do
      CommandBus.dispatch(described_class, export_json: false, publish_release: true)

      release = ReferenceDataRelease.order(published_at: :desc).first
      expect(release.manifest_json["pni_calendars"]).not_to be_empty
    end

    it "deactivates entries removed from the calendar definitions" do
      CommandBus.dispatch(described_class, export_json: false, publish_release: false)
      stale = PniScheduleEntry.create!(
        calendar_year: 2026,
        age_group: "child",
        effective_from: Date.new(2026, 1, 1),
        immunobiological_code: "99",
        immunobiological_name: "Stale vaccine",
        dose_code: "X",
        min_age_days: 0,
        max_age_days: 30,
        active: true
      )

      CommandBus.dispatch(described_class, export_json: false, publish_release: false)

      expect(stale.reload.active).to be(false)
    end

    it "bumps updated_at on re-sync" do
      CommandBus.dispatch(described_class, export_json: false, publish_release: false)
      entry = PniScheduleEntry.active.order(:created_at).first
      original_updated_at = entry.updated_at

      travel 1.minute do
        CommandBus.dispatch(described_class, export_json: false, publish_release: false)
      end

      expect(entry.reload.updated_at).to be > original_updated_at
    end

    it "rejects invalid schedule entries before upsert" do
      invalid_calendar = Reference::PniCalendarDefinitions.child_0_2_2026.deep_dup
      invalid_calendar["entries"] = [
        Reference::PniCalendarDefinitions.entry("15", "BCG", "1", "D1", 30, 0)
      ]
      allow(Reference::PniCalendarLoader).to receive(:load_calendars).and_return([ invalid_calendar ])

      expect do
        CommandBus.dispatch(described_class, export_json: false, publish_release: false)
      end.to raise_error(ArgumentError, /invalid entry 15\/1/)
    end
  end
end

RSpec.describe Reference::Commands::ImportPniCalendar do
  before do
    Reference::DomainSeedImporter.call
  end

  it "records a successful import run" do
    result = CommandBus.dispatch(described_class, export_json: false, publish_release: false)

    run = ReferenceImportRun.order(started_at: :desc).first
    expect(run.status).to eq("succeeded")
    expect(run.records_imported).to eq(result.fetch(:entries))
    expect(run.job_name).to eq("PniCalendarImportJob")
  end
end
