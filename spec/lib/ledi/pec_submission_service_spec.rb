# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ledi::PecSubmissionService do
  let(:municipality) { create(:municipality) }
  let(:batch) { create(:ledi_batch, municipality: municipality, status: "ready") }
  let(:membership) { create(:user_municipality_membership, municipality: municipality, scope: "municipality") }

  def create_validated_record!
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

  it "accepts batch in test when PEC is not configured and records are validated" do
    with_tenant(membership) do
      create_validated_record!
      result = described_class.call(batch: batch)

      expect(result.accepted).to be(true)
    end
  end

  it "rejects empty batch in test when PEC is not configured" do
    with_tenant(membership) do
      result = described_class.call(batch: batch)

      expect(result.accepted).to be(false)
      expect(result.rejection_reason).to include("no validated transport records")
    end
  end

  it "delegates to PecClient when municipality has pec_base_url" do
    municipality.update!(pec_base_url: "http://127.0.0.1:9090", pec_api_token: "secret")
    client = instance_double(Ledi::PecClient, submit_batch: Ledi::PecClient::Response.new(true, nil))
    allow(Ledi::PecClient).to receive(:new).with(base_url: "http://127.0.0.1:9090", api_token: "secret").and_return(client)

    with_tenant(membership) do
      create_validated_record!
      result = described_class.call(batch: batch)

      expect(result.accepted).to be(true)
      expect(client).to have_received(:submit_batch).with(batch: batch)
    end
  end

  it "rejects when PEC client raises a transport error" do
    municipality.update!(pec_base_url: "http://127.0.0.1:9090")
    client = instance_double(Ledi::PecClient)
    allow(client).to receive(:submit_batch).and_raise(Ledi::PecClient::Error, "connection refused")
    allow(Ledi::PecClient).to receive(:new).and_return(client)

    with_tenant(membership) do
      create_validated_record!
      result = described_class.call(batch: batch)

      expect(result.accepted).to be(false)
      expect(result.rejection_reason).to eq("connection refused")
    end
  end

  it "raises when an unexpected error occurs during submission" do
    municipality.update!(pec_base_url: "http://127.0.0.1:9090", pec_api_token: "secret")
    client = instance_double(Ledi::PecClient)
    allow(client).to receive(:submit_batch).and_raise(TypeError, "unexpected failure")
    allow(Ledi::PecClient).to receive(:new).and_return(client)

    with_tenant(membership) do
      create_validated_record!

      expect do
        described_class.call(batch: batch)
      end.to raise_error(TypeError, "unexpected failure")
    end
  end

  it "rejects batch without validated transport records when stub rejection is enabled" do
    original = ENV["LEDI_PEC_STUB_REJECT"]
    ENV["LEDI_PEC_STUB_REJECT"] = "true"

    with_tenant(membership) do
      result = described_class.call(batch: batch)

      expect(result.accepted).to be(false)
      expect(result.rejection_reason).to include("LEDI_PEC_STUB_REJECT")
    end
  ensure
    ENV["LEDI_PEC_STUB_REJECT"] = original
  end

  it "rejects in deployed environments when PEC URL is configured without a municipality token" do
    allow(Rails.env).to receive(:development?).and_return(false)
    allow(Rails.env).to receive(:test?).and_return(false)
    municipality.update!(pec_base_url: "http://127.0.0.1:9090", pec_api_token: nil)
    expect(Ledi::PecClient).not_to receive(:new)

    with_tenant(membership) do
      create_validated_record!
      result = described_class.call(batch: batch)

      expect(result.accepted).to be(false)
      expect(result.rejection_reason).to include("PEC API token not configured")
    end
  end
end
