# frozen_string_literal: true

require "rails_helper"

RSpec.describe Indicators::RecalculateForClinicalRecord do
  before { load Rails.root.join("db/seeds/indicator_catalog.rb") }

  describe ".call" do
    it "recalculates B1 when FAO is persisted for an eSB team" do
      municipality = create(:municipality)
      facility = create(:health_facility, municipality: municipality)
      team = create(:care_team, :esb, municipality: municipality, health_facility: facility)
      citizen = create(:citizen, municipality: municipality, health_facility: facility, care_team: team)
      record = instance_double(
        ClinicalRecord,
        record_type: "FAO",
        citizen: citizen,
        care_team_id: citizen.care_team_id,
        encounter_at: Time.current,
        encounters: Encounter.none
      )

      allow(Indicators::DetectCitizenGaps).to receive(:call).and_return({ gaps_opened: 0, gaps_resolved: 0, citizens_processed: 1 })
      allow(Indicators::RecalculateTeamScore).to receive(:call).and_return([])

      result = described_class.new(clinical_record: record).call

      expect(result[:skipped]).to be(false)
      expect(result[:indicator_codes]).to include("B1")
    end

    it "drops eMulti codes when care team is eSF" do
      municipality = create(:municipality)
      facility = create(:health_facility, municipality: municipality)
      team = create(:care_team, municipality: municipality, health_facility: facility, team_kind: "esf")
      citizen = create(:citizen, municipality: municipality, health_facility: facility, care_team: team)
      record = instance_double(
        ClinicalRecord,
        record_type: "FAI",
        citizen: citizen,
        care_team_id: citizen.care_team_id,
        encounter_at: Time.current,
        encounters: Encounter.none
      )

      allow(Indicators::DetectCitizenGaps).to receive(:call).and_return({ gaps_opened: 0, gaps_resolved: 0, citizens_processed: 1 })
      allow(Indicators::RecalculateTeamScore).to receive(:call).and_return([])

      result = described_class.new(clinical_record: record).call

      expect(result[:indicator_codes]).to include("C4")
      expect(result[:indicator_codes]).not_to include("M1")
    end
  end
end
