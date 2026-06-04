# frozen_string_literal: true

require "rails_helper"

RSpec.describe Reference::PniCalendarLoader do
  before do
    Reference::DomainSeedImporter.call
    CommandBus.dispatch(Reference::Commands::SyncPniCalendar, export_json: false, publish_release: false)
  end

  describe ".audit_report" do
    it "reports no drift after sync" do
      CommandBus.dispatch(Reference::Commands::SyncPniCalendar, export_json: true, publish_release: false)

      report = described_class.audit_report
      expect(report[:drift]).to be_empty
      expect(report[:entries_defined]).to eq(report[:entries_in_db])
    end

    it "exports under the calendar year directory, not PNI_DIR root" do
      CommandBus.dispatch(Reference::Commands::SyncPniCalendar, export_json: true, publish_release: false)

      expect(described_class.export_path_for(Reference::PniCalendarDefinitions.child_0_2_2026)).to exist
      expect(described_class::PNI_DIR.join("child.0_2.json")).not_to exist
    end
  end
end
