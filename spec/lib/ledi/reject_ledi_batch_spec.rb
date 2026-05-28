# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ledi::RejectLediBatch do
  let(:municipality) { create(:municipality) }
  let(:membership) do
    create(:user_municipality_membership, municipality: municipality, scope: "municipality", role_code: "municipal_admin")
  end
  let(:batch) do
    with_tenant(membership) { create(:ledi_batch, municipality: municipality, status: "ready") }
  end

  it "marks batch as rejected with reason" do
    with_tenant(membership) do
      described_class.call(batch: batch, reason: "PEC XSD invalid")
      batch.reload

      expect(batch.status).to eq("rejected")
      expect(batch.rejection_reason).to eq("PEC XSD invalid")
      expect(batch.rejected_at).to be_present
      expect(DomainEvent.where(event_type: "ledi.batch.status_changed", aggregate_id: batch.id).count).to eq(1)
    end
  end

  it "is idempotent when batch is already rejected" do
    with_tenant(membership) do
      described_class.call(batch: batch, reason: "PEC XSD invalid")
      result = described_class.call(batch: batch.reload, reason: "Another reason")

      expect(result.status).to eq("rejected")
      expect(result.rejection_reason).to eq("PEC XSD invalid")
      expect(DomainEvent.where(event_type: "ledi.batch.status_changed", aggregate_id: batch.id).count).to eq(1)
    end
  end

  it "rejects submitted batches until they are ready" do
    submitted_batch = with_tenant(membership) do
      create(:ledi_batch, municipality: municipality, status: "submitted")
    end

    with_tenant(membership) do
      expect do
        described_class.call(batch: submitted_batch, reason: "Too early")
      end.to raise_error(Ledi::Errors::InvalidBatchStateError)
    end
  end
end
