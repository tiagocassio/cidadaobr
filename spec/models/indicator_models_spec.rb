# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Indicator models" do
  let(:municipality) { create(:municipality) }
  let(:facility) { create(:health_facility, municipality: municipality) }
  let(:team) { create(:care_team, municipality: municipality, health_facility: facility) }
  let(:membership) do
    create(:user_municipality_membership, municipality: municipality, scope: "municipality")
  end

  before { load Rails.root.join("db/seeds/indicator_catalog.rb") }

  it "rejects unknown indicator codes on gaps" do
    citizen = with_tenant(membership) { create(:citizen, municipality: municipality, health_facility: facility, care_team: team) }

    gap = with_tenant(membership) do
      CitizenIndicatorGap.new(
        municipality: municipality,
        citizen: citizen,
        care_team: team,
        indicator_code: "UNKNOWN",
        status: "open"
      )
    end

    expect(gap).not_to be_valid
    expect(gap.errors[:indicator_code]).to be_present
  end

  it "rejects duplicate open gaps for the same citizen and indicator" do
    citizen = with_tenant(membership) { create(:citizen, municipality: municipality, health_facility: facility, care_team: team) }

    with_tenant(membership) do
      CitizenIndicatorGap.create!(
        municipality: municipality,
        citizen: citizen,
        care_team: team,
        indicator_code: "C1",
        status: "open"
      )
    end

    duplicate = with_tenant(membership) do
      CitizenIndicatorGap.new(
        municipality: municipality,
        citizen: citizen,
        care_team: team,
        indicator_code: "C1",
        status: "open"
      )
    end

    expect do
      with_tenant(membership) { duplicate.save! }
    end.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "rejects unknown indicator codes on team results" do
    result = with_tenant(membership) do
      TeamIndicatorResult.new(
        municipality: municipality,
        care_team: team,
        indicator_code: "UNKNOWN",
        quadrimester: "2026-Q1"
      )
    end

    expect(result).not_to be_valid
    expect(result.errors.full_messages_for(:indicator_code).join).to include("Portaria 3.493/2024")
  end

  it "allows team results for known Portaria codes when catalog row is inactive" do
    IndicatorCatalog.find_by!(code: "C1").update!(active: false)

    result = with_tenant(membership) do
      TeamIndicatorResult.new(
        municipality: municipality,
        care_team: team,
        indicator_code: "C1",
        quadrimester: "2026-Q1"
      )
    end

    expect(result).to be_valid
  end

  it "rejects gaps when catalog row is inactive" do
    IndicatorCatalog.find_by!(code: "C1").update!(active: false)
    citizen = with_tenant(membership) { create(:citizen, municipality: municipality, health_facility: facility, care_team: team) }

    gap = with_tenant(membership) do
      CitizenIndicatorGap.new(
        municipality: municipality,
        citizen: citizen,
        care_team: team,
        indicator_code: "C1",
        status: "open",
        due_on: Date.current
      )
    end

    expect(gap).not_to be_valid
    expect(gap.errors[:indicator_code]).to be_present
  end
end
