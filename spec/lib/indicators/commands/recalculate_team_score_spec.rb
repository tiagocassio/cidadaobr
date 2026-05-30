# frozen_string_literal: true

require "rails_helper"

RSpec.describe Indicators::RecalculateTeamScore do
  let(:municipality) { create(:municipality) }
  let(:facility) { create(:health_facility, municipality: municipality) }
  let(:team) { create(:care_team, municipality: municipality, health_facility: facility) }
  let(:membership) { create(:user_municipality_membership, municipality: municipality, scope: "municipality") }

  before { load Rails.root.join("db/seeds/indicator_catalog.rb") }

  it "persists team indicator results for dsl_v1 rules" do
    with_tenant(membership) do
      citizen = create(
        :citizen,
        municipality: municipality,
        health_facility: facility,
        care_team: team,
        birth_date: Date.new(1980, 1, 1),
        full_name: "Complete Citizen"
      )
      persist_fcd_for_team_score!(citizen)
      persist_fci_for_team_score!(citizen)
    end

    results = with_tenant(membership) do
      described_class.call(care_team_id: team.id, indicator_codes: %w[V_CAD])
    end

    expect(results.size).to eq(1)
    result = results.first
    expect(result.score).to eq(100.0)
    expect(result.tier).to eq("excellent")
    expect(result.quadrimester).to eq(Indicators::Quadrimester.current)
  end

  def persist_fcd_for_team_score!(citizen)
    transport = TransportRecord.create!(
      municipality: municipality,
      health_facility: facility,
      serialized_uuid: SecureRandom.uuid,
      serialized_type: "FCD",
      cnes: facility.cnes,
      ibge_code: municipality.ibge_code,
      payload_binary: "\x00",
      ledi_version: Rails.application.config.ledi.fetch(:version),
      status: "validated"
    )
    record = ClinicalRecord.create!(
      municipality: municipality,
      health_facility: facility,
      care_team: team,
      transport_record: transport,
      record_type: "FCD",
      record_uuid: SecureRandom.uuid,
      payload_schema_version: Rails.application.config.ledi.fetch(:version),
      validation_status: "valid",
      validation_errors: [],
      payload_json: {
        "microArea" => "01",
        "enderecoLocalPermanencia" => { "nuCep" => "01310100", "logradouro" => "Rua Test", "bairro" => "Centro" }
      },
      encounter_at: 1.month.ago
    )
    Encounter.create!(
      municipality: municipality,
      health_facility: facility,
      care_team: team,
      citizen: citizen,
      clinical_record: record,
      record_type: "FCD",
      encounter_at: 1.month.ago
    )
  end

  def persist_fci_for_team_score!(citizen)
    transport = TransportRecord.create!(
      municipality: municipality,
      health_facility: facility,
      serialized_uuid: SecureRandom.uuid,
      serialized_type: "FCI",
      cnes: facility.cnes,
      ibge_code: municipality.ibge_code,
      payload_binary: "\x00",
      ledi_version: Rails.application.config.ledi.fetch(:version),
      status: "validated"
    )
    record = ClinicalRecord.create!(
      municipality: municipality,
      health_facility: facility,
      care_team: team,
      transport_record: transport,
      record_type: "FCI",
      record_uuid: SecureRandom.uuid,
      payload_schema_version: Rails.application.config.ledi.fetch(:version),
      validation_status: "valid",
      validation_errors: [],
      payload_json: {
        "identificacaoUsuarioCidadao" => {
          "nome" => citizen.full_name,
          "dataNascimento" => citizen.birth_date.iso8601,
          "cpfCidadao" => citizen.cpf
        },
        "dataAtualizacao" => 1.month.ago.iso8601
      },
      encounter_at: 1.month.ago
    )
    Encounter.create!(
      municipality: municipality,
      health_facility: facility,
      care_team: team,
      citizen: citizen,
      clinical_record: record,
      record_type: "FCI",
      encounter_at: 1.month.ago
    )
  end

  it "does not emit team score events when values are unchanged" do
    with_tenant(membership) do
      create(
        :citizen,
        municipality: municipality,
        health_facility: facility,
        care_team: team,
        birth_date: Date.new(1980, 1, 1),
        full_name: "Complete Citizen"
      )
    end

    with_tenant(membership) do
      described_class.call(care_team_id: team.id, indicator_codes: %w[V_CAD])
    end

    allow(RecordPlatformEvent).to receive(:call)

    with_tenant(membership) do
      described_class.call(care_team_id: team.id, indicator_codes: %w[V_CAD])
    end

    expect(RecordPlatformEvent).not_to have_received(:call)
  end
end
