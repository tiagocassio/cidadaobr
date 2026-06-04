# frozen_string_literal: true

require "rails_helper"

RSpec.describe RecalculatePniReleaseJob do
  include ActiveJob::TestHelper

  let(:municipality) { create(:municipality) }
  let(:facility) { create(:health_facility, municipality: municipality) }
  let!(:team) { create(:care_team, municipality: municipality, health_facility: facility) }

  it "dispatches RecalculateTeamScore for each care team in the municipality tenant" do
    dispatched = []
    allow(CommandBus).to receive(:dispatch) do |command, **kwargs|
      dispatched << kwargs if command == Indicators::RecalculateTeamScore
    end

    described_class.perform_now(
      municipality_id: municipality.id,
      reference_date: Date.current.iso8601,
      indicator_codes: %w[C2]
    )

    expect(dispatched.pluck(:care_team_id)).to eq([ team.id ])
    expect(dispatched.first.fetch(:indicator_codes)).to eq(%w[C2])
  end

  it "discards jobs when the municipality no longer exists" do
    allow(CommandBus).to receive(:dispatch)

    described_class.perform_now(municipality_id: SecureRandom.uuid)

    expect(CommandBus).not_to have_received(:dispatch)
  end
end

RSpec.describe Indicators::RecalculateForPniRelease do
  include ActiveJob::TestHelper

  it "enqueues one job per municipality" do
    create_list(:municipality, 2)
    total = Municipality.count

    expect do
      described_class.call
    end.to have_enqueued_job(RecalculatePniReleaseJob).exactly(total).times
  end
end
