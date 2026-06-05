# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ledi::PecSubmissionService do
  let(:municipality) { create(:municipality) }
  let(:batch) { create(:ledi_batch, municipality: municipality, status: "ready") }
  let(:membership) { create(:user_municipality_membership, municipality: municipality, scope: "municipality") }

  it "accepts batch with validated transport records when stub is disabled" do
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

      result = described_class.call(batch: batch)

      expect(result.accepted).to be(true)
    end
  end

  it "accepts batch without transport records when stub is disabled" do
    with_tenant(membership) do
      result = described_class.call(batch: batch)

      expect(result.accepted).to be(true)
    end
  end
end
