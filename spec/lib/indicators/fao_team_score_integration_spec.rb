# frozen_string_literal: true

require "rails_helper"

RSpec.describe Indicators::RecalculateForClinicalRecord, "FAO import integration" do
  before { load Rails.root.join("db/seeds/indicator_catalog.rb") }

  let(:municipality) { create(:municipality) }
  let(:facility) { create(:health_facility, municipality: municipality) }
  let(:team) { create(:care_team, :esb, municipality: municipality, health_facility: facility) }
  let(:membership) { create(:user_municipality_membership, municipality: municipality, scope: "municipality") }

  it "persists B1 team score after FAO clinical record is recalculated" do
    citizen = with_tenant(membership) do
      create(
        :citizen,
        municipality: municipality,
        health_facility: facility,
        care_team: team,
        birth_date: Date.new(1990, 4, 1),
        full_name: "Odonto Test"
      )
    end

    encounter_at = 2.months.ago

    clinical_record = with_tenant(membership) do
      create_indicator_clinical_record!(
        municipality: municipality,
        health_facility: facility,
        care_team: team,
        citizen: citizen,
        record_type: "FAO",
        payload_json: {
          "atendimentos_odontologicos" => [
            { "tipos_consulta_odonto" => [ 1 ], "cpfCidadao" => citizen.cpf }
          ]
        },
        encounter_at: encounter_at
      )
    end

    with_tenant(membership) do
      result = described_class.call(clinical_record: clinical_record)

      expect(result[:skipped]).to be(false)
      expect(result[:indicator_codes]).to include("B1")

      team_result = TeamIndicatorResult.find_by!(
        care_team_id: team.id,
        indicator_code: "B1",
        quadrimester: Indicators::Quadrimester.current(encounter_at.to_date)
      )
      expect(team_result.score).to be > 0
    end
  end
end
