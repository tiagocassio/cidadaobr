# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ledi::BatchPayloadPack do
  it "concatenates validated payloads in id order" do
    municipality = create(:municipality)
    membership = create(:user_municipality_membership, municipality: municipality, scope: "municipality")
    batch = with_tenant(membership) { create(:ledi_batch, municipality: municipality) }

    first = with_tenant(membership) do
      TransportRecord.create!(
        municipality: municipality,
        ledi_batch: batch,
        ibge_code: municipality.ibge_code,
        cnes: "1234567",
        serialized_uuid: SecureRandom.uuid,
        serialized_type: "FCI",
        ledi_version: Rails.application.config.ledi.fetch(:version),
        status: "validated",
        payload_binary: "first"
      )
    end
    second = with_tenant(membership) do
      TransportRecord.create!(
        municipality: municipality,
        ledi_batch: batch,
        ibge_code: municipality.ibge_code,
        cnes: "1234567",
        serialized_uuid: SecureRandom.uuid,
        serialized_type: "FCI",
        ledi_version: Rails.application.config.ledi.fetch(:version),
        status: "validated",
        payload_binary: "second"
      )
    end

    packed = described_class.pack([ second, first ])

    expect(packed).to eq([ first, second ].sort_by { |record| [ record.created_at, record.id ] }.map(&:payload_binary).join)
  end
end
