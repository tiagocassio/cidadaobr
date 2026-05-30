# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Tenant RLS isolation", type: :model do
  let(:municipality) { create(:municipality) }
  let(:facility_a) { create(:health_facility, municipality: municipality, name: "UBS A") }
  let(:facility_b) { create(:health_facility, municipality: municipality, name: "UBS B") }
  let(:membership_a) do
    create(:user_municipality_membership, municipality: municipality, health_facility: facility_a, scope: "facility")
  end
  let(:membership_b) do
    create(:user_municipality_membership, municipality: municipality, health_facility: facility_b, scope: "facility")
  end

  def record_event(membership, facility)
    with_tenant(Cidadaobr::TenantScope.from_membership(membership)) do
      CommandBus.dispatch(
        RecordPlatformEvent,
        event_type: "platform.bootstrapped",
        aggregate_type: "Platform",
        aggregate_id: SecureRandom.uuid,
        payload: { facility_id: facility.id },
        topic: "domain.outbox",
        metadata: {}
      )
    end
  end

  it "prevents cross-facility reads under facility scope" do
    record_event(membership_a, facility_a)
    record_event(membership_b, facility_b)

    visible_ids = with_tenant(Cidadaobr::TenantScope.from_membership(membership_a)) do
      DomainEvent.pluck(:health_facility_id)
    end

    expect(visible_ids).to all(eq(facility_a.id))
    expect(visible_ids).not_to include(facility_b.id)
  end

  it "allows facility scope to read citizens linked only via care team" do
    team = create(:care_team, municipality: municipality, health_facility: facility_a)
    municipal_membership = create(:user_municipality_membership, municipality: municipality, scope: "municipality")
    citizen = with_tenant(Cidadaobr::TenantScope.from_membership(municipal_membership)) do
      create(:citizen, municipality: municipality, health_facility: nil, care_team: team)
    end

    visible = with_tenant(Cidadaobr::TenantScope.from_membership(membership_a)) do
      Citizen.find_by(id: citizen.id)
    end

    expect(visible).to eq(citizen)
  end

  it "prevents cross-facility reads of ledi batches under facility scope" do
    load Rails.root.join("db/seeds/ledi_catalog.rb")

    batch_a = with_tenant(membership_a) do
      clinical_record = Ledi::ImportTransportRecord.call(
        payload_binary: LediFixtures.fci_binary(cnes: facility_a.cnes, ibge: municipality.ibge_code)
      )[:clinical_record]
      Ledi::ValidateClinicalRecord.call(clinical_record_id: clinical_record.id)
      Ledi::SubmitLediBatch.call
    end

    batch_b = with_tenant(membership_b) do
      clinical_record = Ledi::ImportTransportRecord.call(
        payload_binary: LediFixtures.fci_binary(cnes: facility_b.cnes, ibge: municipality.ibge_code)
      )[:clinical_record]
      Ledi::ValidateClinicalRecord.call(clinical_record_id: clinical_record.id)
      Ledi::SubmitLediBatch.call
    end

    visible_batch_ids = with_tenant(Cidadaobr::TenantScope.from_membership(membership_a)) do
      LediBatch.pluck(:id)
    end

    expect(visible_batch_ids).to eq([ batch_a.id ])
    expect(visible_batch_ids).not_to include(batch_b.id)
  end

  it "restricts installations to municipality scope only" do
    municipal_membership = create(:user_municipality_membership, municipality: municipality, scope: "municipality")

    installation = with_tenant(municipal_membership) do
      Installation.create!(
        municipality: municipality,
        counter_key: "counter-001",
        installation_uuid: "00000000-0000-4000-8000-000000000099",
        tax_id: "12345678000199",
        legal_name: "Secretaria Municipal de Saude"
      )
    end

    facility_visible = with_tenant(Cidadaobr::TenantScope.from_membership(membership_a)) do
      Installation.find_by(id: installation.id)
    end
    municipal_visible = with_tenant(Cidadaobr::TenantScope.from_membership(municipal_membership)) do
      Installation.find_by(id: installation.id)
    end

    expect(facility_visible).to be_nil
    expect(municipal_visible).to eq(installation)
  end

  it "prevents cross-facility reads of team indicator results under facility scope" do
    load Rails.root.join("db/seeds/indicator_catalog.rb")

    team_a = create(:care_team, municipality: municipality, health_facility: facility_a)
    team_b = create(:care_team, municipality: municipality, health_facility: facility_b)
    municipal_membership = create(:user_municipality_membership, municipality: municipality, scope: "municipality")

    result_a = with_tenant(Cidadaobr::TenantScope.from_membership(municipal_membership)) do
      TeamIndicatorResult.create!(
        municipality: municipality,
        care_team: team_a,
        indicator_code: "C1",
        quadrimester: "2026-Q1",
        score: 80
      )
    end

    with_tenant(Cidadaobr::TenantScope.from_membership(municipal_membership)) do
      TeamIndicatorResult.create!(
        municipality: municipality,
        care_team: team_b,
        indicator_code: "C1",
        quadrimester: "2026-Q1",
        score: 70
      )
    end

    visible_ids = with_tenant(Cidadaobr::TenantScope.from_membership(membership_a)) do
      TeamIndicatorResult.pluck(:id)
    end

    expect(visible_ids).to eq([ result_a.id ])
  end

  it "prevents cross-facility reads of citizen indicator gaps under facility scope" do
    load Rails.root.join("db/seeds/indicator_catalog.rb")

    team_a = create(:care_team, municipality: municipality, health_facility: facility_a)
    team_b = create(:care_team, municipality: municipality, health_facility: facility_b)
    municipal_membership = create(:user_municipality_membership, municipality: municipality, scope: "municipality")
    citizen_a = with_tenant(Cidadaobr::TenantScope.from_membership(municipal_membership)) do
      create(:citizen, municipality: municipality, health_facility: facility_a, care_team: team_a)
    end
    citizen_b = with_tenant(Cidadaobr::TenantScope.from_membership(municipal_membership)) do
      create(:citizen, municipality: municipality, health_facility: facility_b, care_team: team_b)
    end

    gap_a = with_tenant(Cidadaobr::TenantScope.from_membership(municipal_membership)) do
      CitizenIndicatorGap.create!(
        municipality: municipality,
        citizen: citizen_a,
        care_team: team_a,
        indicator_code: "C1",
        status: "open"
      )
    end

    with_tenant(Cidadaobr::TenantScope.from_membership(municipal_membership)) do
      CitizenIndicatorGap.create!(
        municipality: municipality,
        citizen: citizen_b,
        care_team: team_b,
        indicator_code: "C1",
        status: "open"
      )
    end

    visible_ids = with_tenant(Cidadaobr::TenantScope.from_membership(membership_a)) do
      CitizenIndicatorGap.pluck(:id)
    end

    expect(visible_ids).to eq([ gap_a.id ])
  end

  it "splits health_facilities RLS so citizen policy can load after citizens table exists" do
    base_sql = Cidadaobr::TenantRlsPolicies.health_facilities_base_policies
    citizen_sql = Cidadaobr::TenantRlsPolicies.health_facilities_citizen_access_policy

    expect(base_sql).to include("health_facilities_facility_access")
    expect(base_sql).not_to include("FROM citizens")
    expect(citizen_sql).to include("health_facilities_citizen_access")
    expect(citizen_sql).to include("FROM citizens")
  end
end
