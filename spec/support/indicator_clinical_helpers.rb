# frozen_string_literal: true

module IndicatorClinicalHelpers
  def create_indicator_clinical_record!(municipality:, health_facility:, care_team:, citizen:, record_type:, payload_json:, encounter_at: Time.zone.now)
    transport = TransportRecord.create!(
      municipality: municipality,
      health_facility: health_facility,
      serialized_uuid: SecureRandom.uuid,
      serialized_type: record_type,
      cnes: health_facility.cnes,
      ibge_code: municipality.ibge_code,
      payload_binary: "\x00",
      ledi_version: Rails.application.config.ledi.fetch(:version),
      status: "validated"
    )
    record = ClinicalRecord.create!(
      municipality: municipality,
      health_facility: health_facility,
      care_team: care_team,
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
      health_facility: health_facility,
      care_team: care_team,
      citizen: citizen,
      clinical_record: record,
      record_type: record_type,
      encounter_at: encounter_at
    )
    record
  end

  def create_indicator_fci_pregnant!(municipality:, health_facility:, care_team:, citizen:, encounter_at: 1.month.ago)
    create_indicator_clinical_record!(
      municipality: municipality,
      health_facility: health_facility,
      care_team: care_team,
      citizen: citizen,
      record_type: "FCI",
      payload_json: {
        "identificacaoUsuarioCidadao" => {
          "nome" => citizen.full_name,
          "dataNascimento" => citizen.birth_date&.iso8601,
          "cpfCidadao" => citizen.cpf
        },
        "gestante" => true,
        "dataAtualizacao" => encounter_at.iso8601
      },
      encounter_at: encounter_at
    )
  end
end

RSpec.configure do |config|
  config.include IndicatorClinicalHelpers
end
