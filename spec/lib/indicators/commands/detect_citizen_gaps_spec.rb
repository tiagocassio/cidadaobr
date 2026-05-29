# frozen_string_literal: true

require "rails_helper"

RSpec.describe Indicators::DetectCitizenGaps do
  let(:municipality) { create(:municipality) }
  let(:facility) { create(:health_facility, municipality: municipality) }
  let(:team) { create(:care_team, municipality: municipality, health_facility: facility) }
  let(:membership) { create(:user_municipality_membership, municipality: municipality, scope: "municipality") }

  before { load Rails.root.join("db/seeds/indicator_catalog.rb") }

  it "loads indicator rules once per run" do
    with_tenant(membership) do
      create(:citizen, municipality: municipality, health_facility: facility, care_team: team)
      create(:citizen, municipality: municipality, health_facility: facility, care_team: team, cpf: "52998224725")
    end

    allow(Indicators::RuleCatalog).to receive(:dsl_v1_rules).and_call_original

    with_tenant(membership) do
      described_class.call(indicator_codes: %w[V_CAD])
    end

    expect(Indicators::RuleCatalog).to have_received(:dsl_v1_rules).once
  end

  it "skips citizens without a care team" do
    citizen = with_tenant(membership) do
      create(:citizen, municipality: municipality, health_facility: facility, care_team: nil, cpf: "39053344705")
    end

    with_tenant(membership) do
      result = described_class.call(citizen_id: citizen.id, indicator_codes: %w[V_CAD])
      expect(result[:gaps_opened]).to eq(0)
      expect(CitizenIndicatorGap.where(citizen: citizen).count).to eq(0)
    end
  end

  it "opens and resolves V_CAD gaps" do
    citizen = with_tenant(membership) do
      create(:citizen, municipality: municipality, health_facility: facility, care_team: team, birth_date: nil, full_name: "Incomplete")
    end

    with_tenant(membership) do
      result = described_class.call(citizen_id: citizen.id, indicator_codes: %w[V_CAD])
      expect(result[:gaps_opened]).to eq(1)
      expect(CitizenIndicatorGap.where(citizen: citizen, indicator_code: "V_CAD", status: "open").count).to eq(1)
    end

    with_tenant(membership) do
      citizen.update!(birth_date: Date.new(1990, 1, 1))
    end

    with_tenant(membership) do
      result = described_class.call(citizen_id: citizen.id, indicator_codes: %w[V_CAD])
      expect(result[:gaps_resolved]).to eq(1)
      expect(CitizenIndicatorGap.where(citizen: citizen, indicator_code: "V_CAD", status: "open").count).to eq(0)
    end
  end
end
