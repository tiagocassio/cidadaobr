# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ledi::SubmitPecBatch do
  let(:municipality) { create(:municipality, pec_base_url: "http://127.0.0.1:9090", pec_api_token: "token") }
  let(:membership) do
    create(:user_municipality_membership, municipality: municipality, scope: "municipality", role_code: "municipal_admin")
  end
  let(:batch) do
    with_tenant(membership) { create(:ledi_batch, municipality: municipality, status: "ready") }
  end

  def stub_pec_response(accepted:, reason: nil)
    response = Ledi::PecClient::Response.new(accepted, reason)
    allow(Ledi::PecClient).to receive(:new).and_return(instance_double(Ledi::PecClient, submit_batch: response))
  end

  before do
    with_tenant(membership) do
      TransportRecord.create!(
        municipality: municipality,
        ledi_batch: batch,
        ibge_code: municipality.ibge_code,
        cnes: "1234567",
        serialized_uuid: SecureRandom.uuid,
        serialized_type: "FCI",
        ledi_version: Rails.application.config.ledi.fetch(:version),
        status: "validated",
        payload_binary: "\x00"
      )
    end
  end

  it "marks batch and transport records as submitted when PEC accepts" do
    stub_pec_response(accepted: true)

    with_tenant(membership) do
      described_class.call(batch: batch)
      batch.reload

      expect(batch.status).to eq("submitted")
      expect(batch.transport_records.pluck(:status)).to all(eq("sent"))
      expect(DomainEvent.where(event_type: Cidadaobr::KafkaTopics::LEDI_BATCH_STATUSCHANGED, aggregate_id: batch.id).count).to eq(1)
    end
  end

  it "rejects batch and transport records when PEC rejects" do
    stub_pec_response(accepted: false, reason: "XSD invalid")

    with_tenant(membership) do
      described_class.call(batch: batch)
      batch.reload

      expect(batch.status).to eq("rejected")
      expect(batch.rejection_reason).to include("XSD invalid")
      expect(batch.transport_records.pluck(:status)).to all(eq("rejected"))
    end
  end

  it "returns the batch without calling PEC when already submitted" do
    stub_pec_response(accepted: true)
    with_tenant(membership) do
      described_class.call(batch: batch)
    end

    expect(Ledi::PecSubmissionService).not_to receive(:call)

    with_tenant(membership) do
      result = described_class.call(batch: batch.reload)
      expect(result.status).to eq("submitted")
    end
  end

  it "finalizes a ready batch without re-posting when transport records are already sent" do
    with_tenant(membership) do
      batch.transport_records.update_all(status: "sent")

      expect(Ledi::PecSubmissionService).not_to receive(:call)

      described_class.call(batch: batch.reload)

      expect(batch.reload.status).to eq("submitted")
      expect(DomainEvent.where(event_type: Cidadaobr::KafkaTopics::LEDI_BATCH_STATUSCHANGED, aggregate_id: batch.id).count).to eq(1)
    end
  end

  it "completes submission without re-posting when PEC already accepted over HTTP" do
    with_tenant(membership) do
      batch.update!(pec_accepted_at: 1.minute.ago)

      expect(Ledi::PecSubmissionService).not_to receive(:call)

      described_class.call(batch: batch.reload)

      expect(batch.reload.status).to eq("submitted")
      expect(batch.transport_records.pluck(:status)).to all(eq("sent"))
    end
  end

  it "persists pec_accepted_at after PEC accepts so a retry completes without re-posting" do
    stub_pec_response(accepted: true)
    complete_calls = 0

    with_tenant(membership) do
      allow_any_instance_of(described_class).to receive(:complete_pec_submission!).and_wrap_original do |method, *args|
        complete_calls += 1
        raise "simulated crash" if complete_calls == 1

        method.call(*args)
      end

      expect { described_class.call(batch: batch) }.to raise_error("simulated crash")
      expect(batch.reload.pec_accepted_at).to be_present
      expect(batch.status).to eq("ready")

      expect(Ledi::PecSubmissionService).not_to receive(:call)

      described_class.call(batch: batch.reload)

      expect(batch.reload.status).to eq("submitted")
      expect(batch.transport_records.pluck(:status)).to all(eq("sent"))
    end
  end

  it "raises InvalidBatchStateError when PEC accepts but pec_accepted_at was not persisted" do
    stub_pec_response(accepted: true)

    with_tenant(membership) do
      allow_any_instance_of(described_class).to receive(:persist_pec_accepted!)

      expect do
        described_class.call(batch: batch)
      end.to raise_error(Ledi::Errors::InvalidBatchStateError, /pec_accepted_at was not persisted/)
    end
  end

  it "returns batch without raising when PEC accepts but batch was rejected before finalize" do
    stub_pec_response(accepted: true)

    with_tenant(membership) do
      allow_any_instance_of(described_class).to receive(:persist_pec_accepted!).and_wrap_original do |method|
        batch.update!(status: "rejected", rejection_reason: "concurrent reject")
        method.call
      end

      result = described_class.call(batch: batch)

      expect(result.status).to eq("rejected")
      expect(batch.reload.pec_accepted_at).to be_nil
    end
  end

  it "raises when another worker holds the PEC advisory lock" do
    expect(Ledi::PecSubmissionService).not_to receive(:call)

    connection = LediBatch.connection
    allow(connection).to receive(:select_value).and_call_original
    allow(connection).to receive(:select_value)
      .with(a_string_matching(/pg_try_advisory_lock/))
      .and_return(false)

    with_tenant(membership) do
      expect do
        described_class.call(batch: batch)
      end.to raise_error(Ledi::Errors::PecSubmissionInProgressError)
    end
  end

  it "rejects ready batches with mixed validated and sent transport records" do
    with_tenant(membership) do
      TransportRecord.create!(
        municipality: municipality,
        ledi_batch: batch,
        ibge_code: municipality.ibge_code,
        cnes: "7654321",
        serialized_uuid: SecureRandom.uuid,
        serialized_type: "FCI",
        ledi_version: Rails.application.config.ledi.fetch(:version),
        status: "sent",
        payload_binary: "\x01"
      )

      expect(Ledi::PecSubmissionService).not_to receive(:call)

      described_class.call(batch: batch.reload)

      expect(batch.reload.status).to eq("rejected")
      expect(batch.rejection_reason).to include("inconsistent transport record states")
    end
  end
end
