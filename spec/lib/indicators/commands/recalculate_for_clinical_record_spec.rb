# frozen_string_literal: true

require "rails_helper"

RSpec.describe Indicators::RecalculateForClinicalRecord do
  before { load Rails.root.join("db/seeds/indicator_catalog.rb") }

  describe ".call" do
    it "skips FAO when only B/M catalog codes are stubs (no dsl_v1 yet)" do
      record = instance_double(
        ClinicalRecord,
        record_type: "FAO",
        citizen: nil,
        encounter_at: Time.current,
        encounters: Encounter.none
      )
      allow(record).to receive_message_chain(:encounters, :order, :first).and_return(nil)

      result = described_class.new(clinical_record: record).call

      expect(result[:skipped]).to be(true)
    end

    it "drops stub-only codes from RecordTypeIndex before gap recalculation" do
      municipality = create(:municipality)
      facility = create(:health_facility, municipality: municipality)
      team = create(:care_team, municipality: municipality, health_facility: facility)
      citizen = create(:citizen, municipality: municipality, health_facility: facility, care_team: team)
      record = instance_double(
        ClinicalRecord,
        record_type: "FAI",
        citizen: citizen,
        care_team_id: citizen.care_team_id,
        encounter_at: Time.current,
        encounters: Encounter.none
      )

      allow(Indicators::RecordTypeIndex).to receive(:indicator_codes_for).with("FAI").and_return(%w[C4 B1 M1])
      allow(Indicators::DetectCitizenGaps).to receive(:call).and_return({ gaps_opened: 0, gaps_resolved: 0, citizens_processed: 1 })
      allow(Indicators::RecalculateTeamScore).to receive(:call).and_return([])

      result = described_class.new(clinical_record: record).call

      expect(result[:skipped]).to be(false)
      expect(result[:indicator_codes]).to include("C4")
      expect(result[:indicator_codes]).not_to include("B1", "M1")
      expect(Indicators::DetectCitizenGaps).to have_received(:call).with(
        hash_including(citizen_id: citizen.id, indicator_codes: array_including("C4"))
      )
    end
  end
end
