# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ai::FeatureExtractor do
  let(:municipality) { create(:municipality) }
  let(:facility) { create(:health_facility, municipality: municipality) }
  let(:team) { create(:care_team, municipality: municipality, health_facility: facility) }
  let(:membership) { create(:user_municipality_membership, municipality: municipality, scope: "municipality") }

  def build_record(payload_json:, record_type: "FCI")
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
    ClinicalRecord.create!(
      municipality: municipality,
      health_facility: facility,
      care_team: team,
      transport_record: transport,
      record_type: record_type,
      record_uuid: SecureRandom.uuid,
      payload_schema_version: Rails.application.config.ledi.fetch(:version),
      validation_status: "valid",
      validation_errors: [],
      payload_json: payload_json
    )
  end

  it "extracts demographic and health condition features from FCI payload" do
    birth_epoch = Time.utc(1960, 3, 10).to_i * 1000
    clinical_record = with_tenant(membership) { build_record(
      payload_json: {
        identificacao_usuario_cidadao: {
          data_nascimento_cidadao: birth_epoch,
          sexo_cidadao: 2
        },
        condicoes_de_saude: {
          status_eh_hipertensao_arterial_hta: "1",
          status_tem_diabetes: "0"
        },
        medicamentos: [ { codigo: "B01" }, { codigo: "C10" } ],
        medicoes: {
          pressao_arterial_sistolica: 140,
          pressao_arterial_diastolica: 90
        }
      }
    ) }

    features = described_class.call(clinical_record: clinical_record)

    expect(features[:record_type]).to eq("FCI")
    expect(features[:measurements]).to eq(systolic_bp: 140, diastolic_bp: 90)
    expect(features[:citizen][:age_years]).to be >= 65
    expect(features[:citizen][:sex]).to eq("2")
    expect(features[:health_conditions]).to eq(
      "status_eh_hipertensao_arterial_hta" => true
    )
    expect(features[:medications_count]).to eq(2)
  end

  it "reads camelCase LEDI section keys" do
    birth_epoch = Time.utc(1985, 1, 1).to_i * 1000
    clinical_record = with_tenant(membership) do
      build_record(
        payload_json: {
          identificacaoUsuarioCidadao: {
            dataNascimentoCidadao: birth_epoch,
            sexoCidadao: 1
          },
          condicoesDeSaude: {
            status_eh_hipertensao_arterial_hta: 1
          }
        }
      )
    end

    features = described_class.call(clinical_record: clinical_record)

    expect(features[:citizen][:sex]).to eq("1")
    expect(features[:health_conditions]).to eq("status_eh_hipertensao_arterial_hta" => true)
  end

  it "reads camelCase keys inside condicoesDeSaude" do
    clinical_record = with_tenant(membership) do
      build_record(
        payload_json: {
          condicoesDeSaude: {
            statusEhGestante: 1,
            statusTemDiabetes: 0
          }
        }
      )
    end

    features = described_class.call(clinical_record: clinical_record)

    expect(features[:citizen][:pregnant]).to be(true)
    expect(features[:health_conditions]).to eq("status_eh_gestante" => true)
  end

  it "reads measurements from nested attendance sections" do
    clinical_record = with_tenant(membership) do
      build_record(
        record_type: "FAI",
        payload_json: {
          atendimentos_individuais: [
            {
              medicoes: {
                pressaoArterialSistolica: 130,
                pressaoArterialDiastolica: 85,
                glicemia: 110
              }
            }
          ]
        }
      )
    end

    features = described_class.call(clinical_record: clinical_record)

    expect(features[:measurements]).to eq(systolic_bp: 130, diastolic_bp: 85, glucose: 110)
  end

  it "reads health conditions from situacaoDeSaude section" do
    clinical_record = with_tenant(membership) do
      build_record(
        payload_json: {
          situacaoDeSaude: {
            status_eh_hipertensao_arterial_hta: "1"
          }
        }
      )
    end

    features = described_class.call(clinical_record: clinical_record)

    expect(features[:health_conditions]).to eq("status_eh_hipertensao_arterial_hta" => true)
  end
end
