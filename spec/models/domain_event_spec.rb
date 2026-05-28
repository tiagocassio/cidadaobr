# frozen_string_literal: true

require "rails_helper"

RSpec.describe DomainEvent, type: :model do
  let(:municipality) { create(:municipality) }
  let(:membership) { create(:user_municipality_membership, municipality: municipality) }

  it "is append-only" do
    event = with_tenant(membership) do
      DomainEvent.append!(
        aggregate_type: "Platform",
        aggregate_id: SecureRandom.uuid,
        event_type: "platform.bootstrapped",
        payload: { status: "ok" },
        metadata: {},
        occurred_at: Time.current,
        version: 1
      )
    end

    expect { event.update!(event_type: "changed") }.to raise_error(ActiveRecord::ReadOnlyRecord)
    expect { event.destroy! }.to raise_error(ActiveRecord::ReadOnlyRecord)
  end
end
