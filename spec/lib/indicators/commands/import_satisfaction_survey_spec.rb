# frozen_string_literal: true

require "rails_helper"

RSpec.describe Indicators::ImportSatisfactionSurvey do
  let(:municipality) { create(:municipality) }
  let(:facility) { create(:health_facility, municipality: municipality) }
  let(:team) { create(:care_team, municipality: municipality, health_facility: facility, ine: "0000012345") }

  before { team }

  it "imports scores by team INE" do
    month = Date.new(2026, 3, 1)
    imported = described_class.call(
      municipality: municipality,
      rows: [
        described_class::Row.new(ine: team.ine, reference_month: month, score: 8.5)
      ]
    )

    expect(imported.imported).to eq(1)
    expect(imported.skipped_unknown_ine).to eq(0)
    expect(imported.skipped_invalid).to eq(0)
    record = TeamSatisfactionSurveyScore.find_by(care_team_id: team.id, reference_month: month)
    expect(record.score).to eq(8.5)
  end

  it "skips rows with invalid score" do
    result = described_class.call(
      municipality: municipality,
      rows: [
        described_class::Row.new(ine: team.ine, reference_month: Date.new(2026, 3, 1), score: 11.0)
      ]
    )

    expect(result.imported).to eq(0)
    expect(result.skipped_invalid).to eq(1)
    expect(TeamSatisfactionSurveyScore.count).to eq(0)
  end

  it "counts unknown INE rows as skipped" do
    result = described_class.call(
      municipality: municipality,
      rows: [
        described_class::Row.new(ine: "9999999999", reference_month: Date.new(2026, 3, 1), score: 7.0)
      ]
    )

    expect(result.imported).to eq(0)
    expect(result.skipped_unknown_ine).to eq(1)
  end

  it "counts invalid CSV date rows as skipped_invalid" do
    csv = Tempfile.new([ "sat", ".csv" ])
    csv.write("ine,reference_month,score\n#{team.ine},not-a-date,8.0\n")
    csv.rewind

    result = described_class.from_csv(municipality: municipality, csv_path: csv.path)

    expect(result.imported).to eq(0)
    expect(result.skipped_invalid).to eq(1)
  ensure
    csv&.close!
  end
end
