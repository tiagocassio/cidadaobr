# frozen_string_literal: true

require "rails_helper"

RSpec.describe QueryBus, type: :service do
  let(:municipality) { create(:municipality) }
  let(:facility) { create(:health_facility, municipality: municipality) }
  let(:membership) do
    create(:user_municipality_membership, municipality: municipality, health_facility: facility, scope: "facility")
  end

  it "does not mutate state" do
    with_tenant(membership) do
      CommandBus.dispatch(
        RecordPlatformEvent,
        event_type: "platform.bootstrapped",
        aggregate_type: "Platform",
        aggregate_id: SecureRandom.uuid,
        payload: { boot: true },
        topic: "domain.outbox"
      )

      expect { QueryBus.ask(ListDomainEvents) }.not_to change(OutboxMessage, :count)
    end
  end
end
