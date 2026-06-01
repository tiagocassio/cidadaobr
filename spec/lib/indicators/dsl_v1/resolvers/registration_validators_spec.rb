# frozen_string_literal: true

require "rails_helper"

RSpec.describe Indicators::DslV1::Resolvers::RegistrationValidators do
  let(:municipality) { create(:municipality) }
  let(:facility) { create(:health_facility, municipality: municipality) }
  let(:team) { create(:care_team, municipality: municipality, health_facility: facility) }
  let(:membership) { create(:user_municipality_membership, municipality: municipality, scope: "municipality") }

  def persist_clinical_record!(citizen:, record_type:, payload_json:, encounter_at: Time.zone.now)
    transport = TransportRecord.create!(
      municipality: municipality,
      health_facility: facility,
      serialized_uuid: SecureRandom.uuid,
      serialized_type: record_type,
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
      record_type: record_type,
      record_uuid: SecureRandom.uuid,
      payload_schema_version: Rails.application.config.ledi.fetch(:version),
      validation_status: "valid",
      validation_errors: [],
      payload_json: payload_json,
      encounter_at: encounter_at
    )
    Encounter.create!(
      municipality: municipality,
      health_facility: facility,
      care_team: team,
      citizen: citizen,
      clinical_record: record,
      record_type: record_type,
      encounter_at: encounter_at
    )
    record
  end

  it "requires FCI payload for mici_complete?" do
    citizen = with_tenant(membership) do
      create(
        :citizen,
        municipality: municipality,
        health_facility: facility,
        care_team: team,
        birth_date: Date.new(1980, 1, 1),
        full_name: "Maria Test"
      )
    end

    with_tenant(membership) do
      expect(described_class.mici_complete?(citizen)).to be(false)
    end
  end

  it "accepts MICI from FCI identificacaoUsuarioCidadao" do
    citizen = with_tenant(membership) do
      create(
        :citizen,
        municipality: municipality,
        health_facility: facility,
        care_team: team,
        birth_date: Date.new(1980, 1, 1),
        full_name: "Maria Test"
      )
    end

    with_tenant(membership) do
      persist_clinical_record!(
        citizen: citizen,
        record_type: "FCI",
        payload_json: {
          "identificacaoUsuarioCidadao" => {
            "nome" => citizen.full_name,
            "dataNascimento" => citizen.birth_date.iso8601,
            "cpfCidadao" => citizen.cpf
          }
        }
      )
      expect(described_class.mici_complete?(citizen.reload)).to be(true)
    end
  end

  it "reads fci_updated_at only from FCI dataAtualizacao" do
    citizen = with_tenant(membership) do
      create(
        :citizen,
        municipality: municipality,
        health_facility: facility,
        care_team: team,
        birth_date: Date.new(1980, 1, 1),
        full_name: "Maria Test"
      )
    end
    updated_at = 2.months.ago.change(usec: 0)

    with_tenant(membership) do
      persist_clinical_record!(
        citizen: citizen,
        record_type: "FCI",
        payload_json: {
          "identificacaoUsuarioCidadao" => {
            "nome" => citizen.full_name,
            "dataNascimento" => citizen.birth_date.iso8601,
            "cpfCidadao" => citizen.cpf
          },
          "dataAtualizacao" => updated_at.iso8601
        },
        encounter_at: updated_at
      )
      expect(described_class.fci_updated_at(citizen.reload)).to eq(updated_at)
    end
  end

  it "requires FCD microArea and address for micdt_complete?" do
    citizen = with_tenant(membership) do
      create(
        :citizen,
        municipality: municipality,
        health_facility: facility,
        care_team: team,
        birth_date: Date.new(1980, 1, 1),
        full_name: "Maria Test"
      )
    end

    with_tenant(membership) do
      persist_clinical_record!(
        citizen: citizen,
        record_type: "FCD",
        payload_json: {
          "microArea" => "01",
          "enderecoLocalPermanencia" => { "nuCep" => "01310100", "logradouro" => "Av Paulista" }
        }
      )
      expect(described_class.micdt_complete?(citizen.reload)).to be(true)
    end
  end

  it "requires matching microArea in FCI and FCD for microarea_linked?" do
    citizen = with_tenant(membership) do
      create(
        :citizen,
        municipality: municipality,
        health_facility: facility,
        care_team: team,
        birth_date: Date.new(1980, 1, 1),
        full_name: "Microarea Mismatch"
      )
    end

    with_tenant(membership) do
      persist_clinical_record!(
        citizen: citizen,
        record_type: "FCI",
        payload_json: {
          "identificacaoUsuarioCidadao" => {
            "nome" => citizen.full_name,
            "dataNascimento" => citizen.birth_date.iso8601,
            "cpfCidadao" => citizen.cpf,
            "microArea" => "01"
          },
          "dataAtualizacao" => 1.month.ago.iso8601
        }
      )
      persist_clinical_record!(
        citizen: citizen,
        record_type: "FCD",
        payload_json: {
          "microArea" => "02",
          "enderecoLocalPermanencia" => { "nuCep" => "01310100", "logradouro" => "Av Paulista" }
        }
      )
      expect(described_class.microarea_linked?(citizen.reload)).to be(false)
    end
  end

  it "reads PBF and BPC flags from FCI" do
    citizen = with_tenant(membership) do
      create(
        :citizen,
        municipality: municipality,
        health_facility: facility,
        care_team: team,
        birth_date: Date.new(1980, 1, 1),
        full_name: "Benefícios Test"
      )
    end

    with_tenant(membership) do
      persist_clinical_record!(
        citizen: citizen,
        record_type: "FCI",
        payload_json: {
          "identificacaoUsuarioCidadao" => {
            "nome" => citizen.full_name,
            "dataNascimento" => citizen.birth_date.iso8601,
            "cpfCidadao" => citizen.cpf
          },
          "stRecebeBeneficioBolsaFamilia" => true,
          "stRecebeBPC" => false
        }
      )
      expect(described_class.fci_flag_present?(citizen.reload, "pbf")).to be(true)
      expect(described_class.fci_flag_present?(citizen.reload, "bpc")).to be(false)
    end
  end

  it "links microarea when FCI and FCD microArea match without full MICI fields on citizen row" do
    citizen = with_tenant(membership) do
      create(
        :citizen,
        municipality: municipality,
        health_facility: facility,
        care_team: team,
        birth_date: Date.new(1980, 1, 1),
        full_name: "Microarea Linked"
      )
    end

    with_tenant(membership) do
      persist_clinical_record!(
        citizen: citizen,
        record_type: "FCI",
        payload_json: {
          "identificacaoUsuarioCidadao" => {
            "nome" => citizen.full_name,
            "dataNascimento" => citizen.birth_date.iso8601,
            "cpfCidadao" => citizen.cpf,
            "microArea" => "03"
          }
        }
      )
      persist_clinical_record!(
        citizen: citizen,
        record_type: "FCD",
        payload_json: {
          "microArea" => "03",
          "enderecoLocalPermanencia" => { "nuCep" => "01310100", "logradouro" => "Av Paulista" }
        }
      )
      expect(described_class.microarea_linked?(citizen.reload)).to be(true)
    end
  end

  it "prefers microArea from FCI identificacao over conflicting root microArea" do
    citizen = with_tenant(membership) do
      create(
        :citizen,
        municipality: municipality,
        health_facility: facility,
        care_team: team,
        birth_date: Date.new(1980, 1, 1),
        full_name: "Microarea Ident Priority"
      )
    end

    with_tenant(membership) do
      persist_clinical_record!(
        citizen: citizen,
        record_type: "FCI",
        payload_json: {
          "microArea" => "99",
          "identificacaoUsuarioCidadao" => {
            "nome" => citizen.full_name,
            "dataNascimento" => citizen.birth_date.iso8601,
            "cpfCidadao" => citizen.cpf,
            "microArea" => "03"
          }
        }
      )
      persist_clinical_record!(
        citizen: citizen,
        record_type: "FCD",
        payload_json: {
          "microArea" => "03",
          "enderecoLocalPermanencia" => { "nuCep" => "01310100", "logradouro" => "Av Paulista" }
        }
      )
      expect(described_class.microarea_linked?(citizen.reload)).to be(true)
    end
  end
end
