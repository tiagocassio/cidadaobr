# frozen_string_literal: true

require "rails_helper"

RSpec.describe Indicators::DetectCitizenGaps do
  let(:municipality) { create(:municipality) }
  let(:facility) { create(:health_facility, municipality: municipality) }
  let(:team) { create(:care_team, municipality: municipality, health_facility: facility) }
  let(:membership) { create(:user_municipality_membership, municipality: municipality, scope: "municipality") }

  before { load Rails.root.join("db/seeds/indicator_catalog.rb") }

  def persist_fci_pregnant!(citizen:, encounter_at: 1.month.ago)
    create_indicator_fci_pregnant!(
      municipality: municipality,
      health_facility: facility,
      care_team: team,
      citizen: citizen,
      encounter_at: encounter_at
    )
  end

  def persist_clinical_record!(citizen:, record_type:, payload_json:, encounter_at: Time.zone.now)
    create_indicator_clinical_record!(
      municipality: municipality,
      health_facility: facility,
      care_team: team,
      citizen: citizen,
      record_type: record_type,
      payload_json: payload_json,
      encounter_at: encounter_at
    )
  end

  it "loads indicator rules once per run" do
    with_tenant(membership) do
      create(:citizen, municipality: municipality, health_facility: facility, care_team: team)
      create(:citizen, municipality: municipality, health_facility: facility, care_team: team, cpf: "52998224725")
    end

    allow(Indicators::RuleCatalog).to receive(:dsl_v1_rules).and_call_original

    with_tenant(membership) do
      described_class.call(indicator_codes: %w[V_CAD])
    end

    expect(Indicators::RuleCatalog).to have_received(:dsl_v1_rules).once
  end

  it "skips citizens without a care team" do
    citizen = with_tenant(membership) do
      create(:citizen, municipality: municipality, health_facility: facility, care_team: nil, cpf: "39053344705")
    end

    with_tenant(membership) do
      result = described_class.call(citizen_id: citizen.id, indicator_codes: %w[V_CAD])
      expect(result[:gaps_opened]).to eq(0)
      expect(CitizenIndicatorGap.where(citizen: citizen).count).to eq(0)
    end
  end

  it "opens and resolves V_CAD gaps" do
    citizen = with_tenant(membership) do
      create(:citizen, municipality: municipality, health_facility: facility, care_team: team, birth_date: nil, full_name: "Incomplete")
    end

    with_tenant(membership) do
      result = described_class.call(citizen_id: citizen.id, indicator_codes: %w[V_CAD])
      expect(result[:gaps_opened]).to be >= 2
      expect(CitizenIndicatorGap.where(citizen: citizen, indicator_code: "V_CAD", status: "open").count).to be >= 2
    end

    with_tenant(membership) do
      citizen.update!(birth_date: Date.new(1990, 1, 1), full_name: "Complete Citizen")
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
      fci_transport = TransportRecord.create!(
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
      fci_record = ClinicalRecord.create!(
        municipality: municipality,
        health_facility: facility,
        care_team: team,
        transport_record: fci_transport,
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
        clinical_record: fci_record,
        record_type: "FCI",
        encounter_at: 1.month.ago
      )
    end

    with_tenant(membership) do
      result = described_class.call(citizen_id: citizen.id, indicator_codes: %w[V_CAD])
      expect(result[:gaps_resolved]).to be >= 2
      expect(CitizenIndicatorGap.where(citizen: citizen, indicator_code: "V_CAD", status: "open").count).to eq(0)
    end
  end

  it "does not reuse per-citizen encounter cache across citizens on the same team" do
    reference_date = Date.current
    citizens = with_tenant(membership) do
      [
        create(
          :citizen,
          municipality: municipality,
          health_facility: facility,
          care_team: team,
          birth_date: Date.new(1995, 3, 15),
          full_name: "Gestante Gap OK",
          sex: "female",
          cpf: Cidadaobr::Cpf.generate(39_053_344)
        ),
        create(
          :citizen,
          municipality: municipality,
          health_facility: facility,
          care_team: team,
          birth_date: Date.new(1995, 4, 20),
          full_name: "Gestante Gap Late",
          sex: "female",
          cpf: Cidadaobr::Cpf.generate(52_998_224)
        )
      ]
    end

    citizens.each_with_index do |citizen, index|
      dum_date = reference_date - (2 + index).months
      prenatal_at = dum_date + (index.zero? ? 8.weeks : 14.weeks)
      with_tenant(membership) do
        persist_fci_pregnant!(citizen: citizen, encounter_at: reference_date - 1.month)
        record = persist_clinical_record!(
          citizen: citizen,
          record_type: "FAI",
          payload_json: {
            "dumDaGestante" => dum_date.iso8601,
            "atendimentos_individuais" => [ { "tipo" => "consulta" } ]
          },
          encounter_at: prenatal_at
        )
        record.update_column(:encounter_at, nil)
      end
    end

    with_tenant(membership) do
      described_class.call(care_team_id: team.id, indicator_codes: %w[C3], reference_date: reference_date)
    end

    with_tenant(membership) do
      met_citizen, late_citizen = citizens
      expect(
        CitizenIndicatorGap.where(citizen: met_citizen, indicator_code: "C3", good_practice_code: "A", status: "open")
      ).to be_empty
      expect(
        CitizenIndicatorGap.where(citizen: late_citizen, indicator_code: "C3", good_practice_code: "A", status: "open")
      ).not_to be_empty
    end
  end
end
