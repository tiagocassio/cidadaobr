# frozen_string_literal: true

require "rails_helper"
require "rake"

RSpec.describe "indicators:audit_coverage rake task" do
  def invoke_audit_task
    Rake::Task["indicators:audit_coverage"].reenable
    Rake::Task["indicators:audit_coverage"].invoke
  end

  before do
    Rails.application.load_tasks unless Rake::Task.task_defined?("indicators:audit_coverage")
  end

  def stub_report(overrides = {})
    base = {
      "packs_defined" => 48,
      "packs_on_disk" => 48,
      "packs_unreadable_on_disk" => 0,
      "pack_drift" => [],
      "missing_resolvers" => [],
      "bp_coverage" => []
    }
    allow(Indicators::CoverageAudit).to receive(:full_report).and_return(base.merge(overrides))
    allow(Indicators::CoverageAudit).to receive(:misaligned_bp_coverage).and_return([])
  end

  it "exits 0 when coverage report is clean" do
    stub_report

    expect { invoke_audit_task }.not_to raise_error
  end

  it "exits 1 when pack file count mismatches definitions" do
    stub_report("packs_on_disk" => 47)

    expect { invoke_audit_task }.to raise_error(SystemExit) do |error|
      expect(error.status).to eq(1)
    end
  end

  it "exits 1 when pack_drift includes invalid JSON" do
    stub_report("pack_drift" => [ "invalid_json: broken.json(unexpected token)" ])

    expect { invoke_audit_task }.to raise_error(SystemExit) do |error|
      expect(error.status).to eq(1)
    end
  end

  it "exits 1 when unreadable pack files exist on disk" do
    stub_report("packs_unreadable_on_disk" => 1)

    expect { invoke_audit_task }.to raise_error(SystemExit) do |error|
      expect(error.status).to eq(1)
    end
  end
end
