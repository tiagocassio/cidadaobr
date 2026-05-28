# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ledi::ImportTransportRecord do
  let(:municipality) { create(:municipality, ibge_code: "3550308") }
  let(:facility) { create(:health_facility, municipality: municipality, cnes: "2000001") }
  let(:membership) do
    create(:user_municipality_membership, municipality: municipality, health_facility: facility, scope: "facility")
  end

  before do
    load Rails.root.join("db/seeds/ledi_catalog.rb")
  end

  it "persists transport and clinical records and emits imported event" do
    binary = LediFixtures.fci_binary(cnes: facility.cnes, ibge: municipality.ibge_code)

    result = with_tenant(membership) do
      import_result = described_class.call(payload_binary: binary)
      expect(DomainEvent.where(event_type: "clinical.record.imported").count).to eq(1)
      import_result
    end

    expect(result[:transport_record]).to be_persisted
    expect(result[:clinical_record].record_type).to eq("FCI")
  end

  it "creates clinical record items for FAI master payloads" do
    binary = LediFixtures.fai_binary(cnes: facility.cnes, ibge: municipality.ibge_code)

    result = with_tenant(membership) do
      import_result = described_class.call(payload_binary: binary)
      expect(import_result[:clinical_record].clinical_record_items.count).to eq(1)
      import_result
    end

    expect(result[:clinical_record].record_type).to eq("FAI")
  end

  it "is idempotent for the same serialized uuid" do
    binary = LediFixtures.fci_binary(cnes: facility.cnes, ibge: municipality.ibge_code)

    with_tenant(membership) do
      first = described_class.call(payload_binary: binary)
      second = described_class.call(payload_binary: binary)

      expect(second[:reimported]).to be(true)
      expect(second[:transport_record].id).to eq(first[:transport_record].id)
      expect(second[:clinical_record].id).to eq(first[:clinical_record].id)
      expect(TransportRecord.count).to eq(1)
      expect(ClinicalRecord.count).to eq(1)
    end
  end

  it "falls back to municipality ibge when transport header omits cod_ibge" do
    binary = LediFixtures.fci_binary(cnes: facility.cnes, ibge: nil)

    result = with_tenant(membership) do
      described_class.call(payload_binary: binary)
    end

    expect(result[:transport_record].ibge_code).to eq(municipality.ibge_code)
  end

  it "resolves care_team_id from transport INE" do
    care_team = create(:care_team, municipality: municipality, health_facility: facility, ine: "3000000001")
    binary = LediFixtures.fci_binary(cnes: facility.cnes, ibge: municipality.ibge_code, ine: care_team.ine)

    result = with_tenant(membership) do
      described_class.call(payload_binary: binary)
    end

    expect(result[:transport_record].care_team_id).to eq(care_team.id)
    expect(result[:clinical_record].care_team_id).to eq(care_team.id)
  end

  it "refreshes payload when the same serialized uuid arrives with different bytes" do
    serialized_uuid = SecureRandom.uuid
    binary = LediFixtures.fci_binary(
      cnes: facility.cnes,
      ibge: municipality.ibge_code,
      cpf: "39053344705",
      serialized_uuid: serialized_uuid
    )
    updated_binary = LediFixtures.fci_binary(
      cnes: facility.cnes,
      ibge: municipality.ibge_code,
      cpf: "52998224725",
      serialized_uuid: serialized_uuid
    )

    with_tenant(membership) do
      first = described_class.call(payload_binary: binary)
      second = described_class.call(payload_binary: updated_binary)

      expect(second[:reimported]).to be(true)
      expect(second[:refreshed]).to be(true)
      expect(second[:transport_record].id).to eq(first[:transport_record].id)
      expect(second[:clinical_record].payload_json.dig("identificacao_usuario_cidadao", "cpf_cidadao")).to eq("52998224725")
      expect(second[:clinical_record].validation_status).to eq("pending")
      expect(DomainEvent.where(event_type: "clinical.record.imported").count).to eq(2)
      imported_event = DomainEvent.order(:version).where(event_type: "clinical.record.imported").last
      expect(imported_event.payload).to include(
        "refreshed" => true,
        "previous_transport_status" => "draft"
      )
      expect(TransportRecord.count).to eq(1)
    end
  end

  it "raises when refreshing a transport record already assigned to a batch" do
    serialized_uuid = SecureRandom.uuid
    binary = LediFixtures.fci_binary(
      cnes: facility.cnes,
      ibge: municipality.ibge_code,
      serialized_uuid: serialized_uuid
    )
    updated_binary = LediFixtures.fci_binary(
      cnes: facility.cnes,
      ibge: municipality.ibge_code,
      cpf: "52998224725",
      serialized_uuid: serialized_uuid
    )

    with_tenant(membership) do
      transport = described_class.call(payload_binary: binary)[:transport_record]
      clinical_record = transport.clinical_record
      Ledi::ValidateClinicalRecord.call(clinical_record_id: clinical_record.id)
      Ledi::SubmitLediBatch.call

      expect do
        described_class.call(payload_binary: updated_binary)
      end.to raise_error(Ledi::Errors::ImmutableTransportRecordError)
    end
  end

  it "raises when transport header includes an unknown INE" do
    binary = LediFixtures.fci_binary(
      cnes: facility.cnes,
      ibge: municipality.ibge_code,
      ine: "9999999999"
    )

    expect do
      with_tenant(membership) { described_class.call(payload_binary: binary) }
    end.to raise_error(Ledi::Errors::UnknownCareTeamError)
  end
end
