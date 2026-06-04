# frozen_string_literal: true

require "rails_helper"

RSpec.describe Indicators::PniScheduleEvaluator do
  let(:municipality) { create(:municipality) }
  let(:facility) { create(:health_facility, municipality: municipality) }
  let(:team) { create(:care_team, municipality: municipality, health_facility: facility) }
  let(:membership) do
    create(:user_municipality_membership, municipality: municipality, health_facility: facility, scope: "facility")
  end
  let(:citizen) do
    create(
      :citizen,
      municipality: municipality,
      health_facility: facility,
      care_team: team,
      birth_date: Date.current - 18.months
    )
  end

  before { sync_pni_calendar!(export_json: false, publish_release: false) }

  it "returns compliant when all required doses are recorded on time" do
    with_tenant(membership) do
      seed_pni_compliant_immunizations!(citizen: citizen)

      result = described_class.evaluate(citizen: citizen, reference_date: Date.current)

      expect(result.compliant).to be(true)
      expect(result.missing).to be_empty
      expect(result.release_key).to include("2026:child:")
    end
  end

  it "returns missing doses when a required vaccine is absent" do
    with_tenant(membership) do
      seed_pni_compliant_immunizations!(citizen: citizen)
      CitizenImmunizationRecord.where(citizen: citizen, vaccine_code: "15").delete_all

      result = described_class.evaluate(citizen: citizen, reference_date: Date.current)

      expect(result.compliant).to be(false)
      expect(result.missing.map { |row| row[:immunobiological_code] }).to include("15")
    end
  end

  it "ignores doses applied outside the PNI age window" do
    with_tenant(membership) do
      entry = PniScheduleEntry.find_by!(immunobiological_code: "15", dose_code: "1")
      CitizenImmunizationRecord.create!(
        municipality: municipality,
        citizen: citizen,
        vaccine_code: entry.immunobiological_code,
        dose_label: entry.dose_code,
        vaccine_name: entry.immunobiological_name,
        applied_on: citizen.birth_date + (entry.max_age_days + 5).days
      )

      result = described_class.evaluate(citizen: citizen, reference_date: Date.current)

      expect(result.compliant).to be(false)
      expect(result.missing.map { |row| row[:immunobiological_code] }).to include("15")
    end
  end
end
