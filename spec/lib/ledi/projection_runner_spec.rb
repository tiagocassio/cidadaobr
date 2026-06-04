# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ledi::ProjectionRunner do
  let(:municipality) { create(:municipality, ibge_code: "3550308") }
  let(:facility) { create(:health_facility, municipality: municipality, cnes: "2000001") }
  let(:membership) do
    create(:user_municipality_membership, municipality: municipality, health_facility: facility, scope: "facility")
  end

  before do
    load Rails.root.join("db/seeds/ledi_catalog.rb")
  end

  def import(type)
    binary =
      case type
      when :fci then LediFixtures.fci_binary(cnes: facility.cnes, ibge: municipality.ibge_code)
      when :fcd then LediFixtures.fcd_binary(cnes: facility.cnes, ibge: municipality.ibge_code)
      when :fai then LediFixtures.fai_binary(cnes: facility.cnes, ibge: municipality.ibge_code)
      end

    with_tenant(membership) do
      Ledi::ImportTransportRecord.call(payload_binary: binary)[:clinical_record]
    end
  end

  it "projects FCI into citizens and emits citizen.registered" do
    clinical_record = import(:fci)

    with_tenant(membership) do
      described_class.call(clinical_record: clinical_record)

      citizen = Citizen.find_by(municipality_id: municipality.id, cpf: "39053344705")
      expect(citizen.full_name).to eq("Maria da Silva")
      expect(DomainEvent.where(event_type: Cidadaobr::KafkaTopics::CITIZEN_REGISTERED).count).to eq(1)
    end
  end

  it "projects FCD into households and members" do
    clinical_record = import(:fcd)

    with_tenant(membership) do
      described_class.call(clinical_record: clinical_record)

      household = Household.find_by(municipality_id: municipality.id, clinical_record_id: clinical_record.id)
      expect(household.street).to eq("Rua das Flores")
      expect(household.household_members.count).to eq(1)
      expect(household.location).to be_present
      expect(household.coordinates[:lat]).to be_within(0.0001).of(-23.5505)
      expect(household.coordinates[:lng]).to be_within(0.0001).of(-46.6333)
    end
  end

  it "projects FAI items into encounters" do
    clinical_record = import(:fai)

    with_tenant(membership) do
      described_class.call(clinical_record: clinical_record)

      expect(Encounter.where(clinical_record_id: clinical_record.id).count).to eq(1)
    end
  end

  it "projects FV into citizen_immunization_records for an existing citizen" do
    fci_record = import(:fci)

    with_tenant(membership) do
      described_class.call(clinical_record: fci_record)
      citizen = Citizen.find_by!(municipality_id: municipality.id, cpf: "39053344705")

      fv_record = ClinicalRecord.create!(
        municipality: municipality,
        health_facility: facility,
        transport_record: fci_record.transport_record,
        record_type: "FV",
        record_uuid: SecureRandom.uuid,
        payload_schema_version: Rails.application.config.ledi.fetch(:version),
        validation_status: "valid",
        validation_errors: [],
        payload_json: {
          "identificacao" => { "cpf" => citizen.cpf },
          "vacina" => { "codigo" => "15", "nome" => "BCG" },
          "dose" => { "rotulo" => "1" },
          "data_aplicacao" => "2024-01-15"
        }
      )

      described_class.call(clinical_record: fv_record)

      immunization = CitizenImmunizationRecord.find_by!(citizen: citizen, vaccine_code: "15", dose_label: "1")
      expect(immunization.vaccine_name).to eq("BCG")
      expect(immunization.applied_on).to eq(Date.new(2024, 1, 15))
      expect(immunization.source).to eq("fv_projection")
    end
  end

  it "projects nested LEDI vacinacoes into multiple citizen_immunization_records" do
    fci_record = import(:fci)

    with_tenant(membership) do
      described_class.call(clinical_record: fci_record)
      citizen = Citizen.find_by!(municipality_id: municipality.id, cpf: "39053344705")

      fv_record = ClinicalRecord.create!(
        municipality: municipality,
        health_facility: facility,
        transport_record: fci_record.transport_record,
        record_type: "FV",
        record_uuid: SecureRandom.uuid,
        payload_schema_version: Rails.application.config.ledi.fetch(:version),
        validation_status: "valid",
        validation_errors: [],
        payload_json: {
          "vacinacoes" => [
            {
              "cpfCidadao" => citizen.cpf,
              "dataAtendimento" => "2024-02-10",
              "vacinas" => [
                { "imunobiologico" => 15, "dose" => "1" },
                { "imunobiologico" => 45, "dose" => "1" }
              ]
            }
          ]
        },
        encounter_at: Time.zone.parse("2024-02-10")
      )

      described_class.call(clinical_record: fv_record)

      bcg = CitizenImmunizationRecord.find_by!(citizen: citizen, vaccine_code: "15", dose_label: "1")
      hepb = CitizenImmunizationRecord.find_by!(citizen: citizen, vaccine_code: "45", dose_label: "1")
      expect(bcg.applied_on).to eq(Date.new(2024, 2, 10))
      expect(hepb.applied_on).to eq(Date.new(2024, 2, 10))
    end
  end
end
