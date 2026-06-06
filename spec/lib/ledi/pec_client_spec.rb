# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ledi::PecClient do
  let(:municipality) { create(:municipality) }
  let(:membership) { create(:user_municipality_membership, municipality: municipality, scope: "municipality") }
  let(:batch) do
    with_tenant(membership) do
      create(:ledi_batch, municipality: municipality, status: "ready", batch_number: 42)
    end
  end

  def stub_http_response(body:, success: true, code: success ? "200" : "400")
    response = double("http_response", body: body, code: code)
    allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(success)
    http = instance_double(Net::HTTP)
    allow(http).to receive(:request).and_return(response)
    allow(Net::HTTP).to receive(:start).and_yield(http)
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
        payload_binary: "payload-a"
      )
      TransportRecord.create!(
        municipality: municipality,
        ledi_batch: batch,
        ibge_code: municipality.ibge_code,
        cnes: "1234567",
        serialized_uuid: SecureRandom.uuid,
        serialized_type: "FCI",
        ledi_version: Rails.application.config.ledi.fetch(:version),
        status: "validated",
        payload_binary: "payload-b"
      )
    end
  end

  it "posts concatenated validated payloads to the municipal PEC endpoint" do
    stub_http_response(body: { status: "accepted" }.to_json)

    result = with_tenant(membership) do
      client = described_class.new(base_url: "https://pec.example", api_token: "secret")
      client.submit_batch(batch: batch.reload)
    end

    expect(result.accepted).to be(true)
    expect(result.rejection_reason).to be_nil
    expect(Net::HTTP).to have_received(:start).with(
      "pec.example",
      443,
      hash_including(use_ssl: true)
    )
  end

  it "returns rejection when PEC responds with rejected status" do
    stub_http_response(body: { status: "rejected", reason: "XSD invalid" }.to_json)

    result = with_tenant(membership) do
      described_class.new(base_url: "http://127.0.0.1:9090").submit_batch(batch: batch.reload)
    end

    expect(result.accepted).to be(false)
    expect(result.rejection_reason).to eq("XSD invalid")
  end

  it "maps HTTP errors to rejected responses" do
    stub_http_response(body: "invalid batch", success: false, code: "400")

    result = with_tenant(membership) do
      described_class.new(base_url: "http://127.0.0.1:9090").submit_batch(batch: batch.reload)
    end

    expect(result.accepted).to be(false)
    expect(result.rejection_reason).to include("PEC HTTP 400")
  end

  it "preserves path prefix in pec_base_url" do
    stub_http_response(body: { status: "accepted" }.to_json)
    captured_uri = nil
    allow(Net::HTTP::Post).to receive(:new).and_wrap_original do |method, uri|
      captured_uri = uri
      method.call(uri)
    end

    with_tenant(membership) do
      described_class.new(base_url: "https://pec.example/municipio").submit_batch(batch: batch.reload)
    end

    expect(captured_uri.to_s).to eq("https://pec.example/municipio/api/v1/ledi/lotes/42")
  end

  it "returns after exhausting retries on persistent 503 responses" do
    response = double("http_response", body: "unavailable", code: "503")
    allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(false)
    http = instance_double(Net::HTTP)
    allow(http).to receive(:request).and_return(response)
    allow(Net::HTTP).to receive(:start).and_yield(http)

    result = with_tenant(membership) do
      described_class.new(base_url: "http://127.0.0.1:9090").submit_batch(batch: batch.reload)
    end

    expect(result.accepted).to be(false)
    expect(result.rejection_reason).to include("PEC HTTP 503")
    expect(http).to have_received(:request).exactly(3).times
  end

  it "rejects non-JSON success bodies" do
    stub_http_response(body: "<html>error</html>")

    result = with_tenant(membership) do
      described_class.new(base_url: "http://127.0.0.1:9090").submit_batch(batch: batch.reload)
    end

    expect(result.accepted).to be(false)
    expect(result.rejection_reason).to eq("PEC response is not valid JSON")
  end

  it "raises when batch has no validated transport records" do
    with_tenant(membership) { batch.transport_records.update_all(status: "pending") }

    expect do
      with_tenant(membership) do
        described_class.new(base_url: "http://127.0.0.1:9090").submit_batch(batch: batch.reload)
      end
    end.to raise_error(Ledi::PecClient::Error, /no validated transport records/)
  end
end
