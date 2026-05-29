# frozen_string_literal: true

require "rails_helper"

RSpec.describe Indicators::DslV1::Evaluator do
  let(:municipality) { create(:municipality) }
  let(:facility) { create(:health_facility, municipality: municipality) }
  let(:team) { create(:care_team, municipality: municipality, health_facility: facility) }
  let(:membership) { create(:user_municipality_membership, municipality: municipality, scope: "municipality") }

  before { load Rails.root.join("db/seeds/indicator_catalog.rb") }

  def expression_for(code)
    IndicatorCatalog.find_by!(code: code).indicator_rules.first.expression
  end

  def persist_clinical_record!(citizen:, record_type:, payload_json:, encounter_at: Time.zone.now)
    transport = TransportRecord.create!(
      municipality: municipality,
      health_facility: facility,
      serialized_uuid: SecureRandom.uuid,
      serialized_type: record_type,
      cnes: facility.cnes,
      ibge_code: municipality.ibge_code,
      payload_binary: "\x00",
      ledi_version: Rails.application.config.ledi.fetch(:version),
      status: "validated"
    )
    record = ClinicalRecord.create!(
      municipality: municipality,
      health_facility: facility,
      care_team: team,
      transport_record: transport,
      record_type: record_type,
      record_uuid: SecureRandom.uuid,
      payload_schema_version: Rails.application.config.ledi.fetch(:version),
      validation_status: "valid",
      validation_errors: [],
      payload_json: payload_json,
      encounter_at: encounter_at
    )
    Encounter.create!(
      municipality: municipality,
      health_facility: facility,
      care_team: team,
      citizen: citizen,
      clinical_record: record,
      record_type: record_type,
      encounter_at: encounter_at
    )
    record
  end

  it "detects incomplete registration for V_CAD" do
    citizen = with_tenant(membership) do
      create(:citizen, municipality: municipality, health_facility: facility, care_team: team, birth_date: nil)
    end

    result = described_class.evaluate(
      expression: expression_for("V_CAD"),
      context: Indicators::DslV1::Context.new(citizen: citizen)
    )

    expect(result.in_denominator).to be(true)
    expect(result.meets_numerator).to be(false)
  end

  it "resolves complete registration for V_CAD" do
    citizen = with_tenant(membership) do
      create(
        :citizen,
        municipality: municipality,
        health_facility: facility,
        care_team: team,
        birth_date: Date.new(1980, 1, 1),
        full_name: "Maria Test"
      )
    end

    result = described_class.evaluate(
      expression: expression_for("V_CAD"),
      context: Indicators::DslV1::Context.new(citizen: citizen)
    )

    expect(result.meets_numerator).to be(true)
  end

  it "computes team score from citizens in denominator" do
    citizens = with_tenant(membership) do
      [
        create(:citizen, municipality: municipality, health_facility: facility, care_team: team, birth_date: Date.new(1980, 1, 1), full_name: "A"),
        create(:citizen, municipality: municipality, health_facility: facility, care_team: team, birth_date: nil, full_name: "B")
      ]
    end

    score = with_tenant(membership) do
      described_class.team_score(
        expression: expression_for("V_CAD"),
        citizens: Citizen.where(id: citizens.map(&:id)),
        quadrimester: "2026-Q1"
      )
    end

    expect(score).to eq(50.0)
  end

  it "scores CVAT when FV payload has immunizations" do
    citizen = with_tenant(membership) do
      create(
        :citizen,
        municipality: municipality,
        health_facility: facility,
        care_team: team,
        birth_date: Date.new(2020, 6, 1),
        full_name: "Vacina Test"
      )
    end

    with_tenant(membership) do
      persist_clinical_record!(
        citizen: citizen,
        record_type: "FV",
        payload_json: { "vacina" => { "codigo" => "BCG" } },
        encounter_at: 2.months.ago
      )
    end

    result = with_tenant(membership) do
      described_class.evaluate(
        expression: expression_for("CVAT"),
        context: Indicators::DslV1::Context.new(citizen: citizen, reference_date: Date.current)
      )
    end

    expect(result.in_denominator).to be(true)
    expect(result.meets_numerator).to be(true)
  end

  it "excludes citizens over max age from C2 denominator" do
    citizen = with_tenant(membership) do
      create(
        :citizen,
        municipality: municipality,
        health_facility: facility,
        care_team: team,
        birth_date: Date.current - 3.years,
        full_name: "Adulto Test"
      )
    end

    result = described_class.evaluate(
      expression: expression_for("C2"),
      context: Indicators::DslV1::Context.new(citizen: citizen, reference_date: Date.current)
    )

    expect(result.in_denominator).to be(false)
  end

  it "scores C2 when FAI has child development markers" do
    citizen = with_tenant(membership) do
      create(
        :citizen,
        municipality: municipality,
        health_facility: facility,
        care_team: team,
        birth_date: Date.current - 18.months,
        full_name: "Criança Test"
      )
    end

    with_tenant(membership) do
      persist_clinical_record!(
        citizen: citizen,
        record_type: "FAI",
        payload_json: { "desenvolvimento_infantil" => { "avaliado" => true } },
        encounter_at: 1.month.ago
      )
    end

    result = with_tenant(membership) do
      described_class.evaluate(
        expression: expression_for("C2"),
        context: Indicators::DslV1::Context.new(citizen: citizen, reference_date: Date.current)
      )
    end

    expect(result.in_denominator).to be(true)
    expect(result.meets_numerator).to be(true)
  end

  it "scores V_SAT when encounter exists within six months" do
    citizen = with_tenant(membership) do
      create(
        :citizen,
        municipality: municipality,
        health_facility: facility,
        care_team: team,
        birth_date: Date.new(1975, 3, 10),
        full_name: "Satisfação Proxy"
      )
    end

    with_tenant(membership) do
      Encounter.create!(
        municipality: municipality,
        health_facility: facility,
        care_team: team,
        citizen: citizen,
        record_type: "FAI",
        encounter_at: 4.months.ago
      )
    end

    result = with_tenant(membership) do
      described_class.evaluate(
        expression: expression_for("V_SAT"),
        context: Indicators::DslV1::Context.new(citizen: citizen, reference_date: Date.current)
      )
    end

    expect(result.in_denominator).to be(true)
    expect(result.meets_numerator).to be(true)
  end
end
