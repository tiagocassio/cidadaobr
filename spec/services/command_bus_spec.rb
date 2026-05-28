# frozen_string_literal: true

require "rails_helper"

RSpec.describe CommandBus, type: :service do
  let(:municipality) { create(:municipality) }
  let(:facility_a) { create(:health_facility, municipality: municipality) }
  let(:membership) do
    create(:user_municipality_membership, municipality: municipality, health_facility: facility_a, scope: "facility")
  end

  it "persists a domain event through a command" do
    with_tenant(membership) do
      created_event = CommandBus.dispatch(
        RecordPlatformEvent,
        event_type: "platform.bootstrapped",
        aggregate_type: "Platform",
        aggregate_id: SecureRandom.uuid,
        payload: { boot: true },
        topic: "domain.outbox"
      )

      expect(created_event).to be_persisted
      expect(OutboxMessage.find_by(domain_event_id: created_event.id)).to be_present
    end
  end
end
