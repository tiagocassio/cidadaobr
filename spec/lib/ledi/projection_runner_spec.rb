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
      expect(DomainEvent.where(event_type: "citizen.registered").count).to eq(1)
    end
  end

  it "projects FCD into households and members" do
    clinical_record = import(:fcd)

    with_tenant(membership) do
      described_class.call(clinical_record: clinical_record)

      household = Household.find_by(municipality_id: municipality.id, clinical_record_id: clinical_record.id)
      expect(household.street).to eq("Rua das Flores")
      expect(household.household_members.count).to eq(1)
    end
  end

  it "projects FAI items into encounters" do
    clinical_record = import(:fai)

    with_tenant(membership) do
      described_class.call(clinical_record: clinical_record)

      expect(Encounter.where(clinical_record_id: clinical_record.id).count).to eq(1)
    end
  end
end
