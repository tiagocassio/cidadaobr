# frozen_string_literal: true

require "rails_helper"

RSpec.describe Indicators::DslV1::Evaluator do
  let(:municipality) { create(:municipality) }
  let(:facility) { create(:health_facility, municipality: municipality) }
  let(:team) { create(:care_team, municipality: municipality, health_facility: facility) }
  let(:membership) { create(:user_municipality_membership, municipality: municipality, scope: "municipality") }

  before { load Rails.root.join("db/seeds/indicator_catalog.rb") }

  def expression_for(code, rule_code: "default")
    IndicatorRule.joins(:indicator_catalog).find_by!(indicator_catalog: { code: code }, rule_code: rule_code).expression
  end

  def persist_fcd!(citizen:, care_team: team, encounter_at: 1.month.ago)
    persist_clinical_record!(
      citizen: citizen,
      record_type: "FCD",
      care_team: care_team,
      payload_json: {
        "microArea" => "01",
        "enderecoLocalPermanencia" => { "nuCep" => "01310100", "logradouro" => "Av Paulista", "bairro" => "Bela Vista" }
      },
      encounter_at: encounter_at
    )
  end

  def persist_fci!(citizen:, care_team: team, encounter_at: 1.month.ago)
    persist_clinical_record!(
      citizen: citizen,
      record_type: "FCI",
      care_team: care_team,
      payload_json: {
        "identificacaoUsuarioCidadao" => {
          "nome" => citizen.full_name,
          "dataNascimento" => citizen.birth_date&.iso8601,
          "cpfCidadao" => citizen.cpf
        },
        "dataAtualizacao" => encounter_at.iso8601
      },
      encounter_at: encounter_at
    )
  end

  def persist_fci_pregnant!(citizen:, care_team: team, encounter_at: 1.month.ago)
    create_indicator_fci_pregnant!(
      municipality: municipality,
      health_facility: facility,
      care_team: care_team,
      citizen: citizen,
      encounter_at: encounter_at
    )
  end

  def persist_fci_diabetic!(citizen:, care_team: team, encounter_at: 1.month.ago)
    persist_clinical_record!(
      citizen: citizen,
      record_type: "FCI",
      care_team: care_team,
      payload_json: {
        "identificacaoUsuarioCidadao" => {
          "nome" => citizen.full_name,
          "dataNascimento" => citizen.birth_date&.iso8601,
          "cpfCidadao" => citizen.cpf
        },
        "diabetes" => true,
        "dataAtualizacao" => encounter_at.iso8601
      },
      encounter_at: encounter_at
    )
  end

  def persist_clinical_record!(citizen:, record_type:, payload_json:, encounter_at: Time.zone.now, care_team: team)
    create_indicator_clinical_record!(
      municipality: municipality,
      health_facility: facility,
      care_team: care_team,
      citizen: citizen,
      record_type: record_type,
      payload_json: payload_json,
      encounter_at: encounter_at
    )
  end

  it "detects incomplete registration for V_CAD" do
    citizen = with_tenant(membership) do
      create(:citizen, municipality: municipality, health_facility: facility, care_team: team, birth_date: nil)
    end

    result = with_tenant(membership) do
      described_class.evaluate(
        expression: expression_for("V_CAD"),
        context: Indicators::DslV1::Context.new(citizen: citizen)
      )
    end

    expect(result.in_denominator).to be(true)
    expect(result.meets_numerator).to be(false)
  end

  it "resolves complete registration for V_CAD when MICI and MICDT are present" do
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

    with_tenant(membership) do
      persist_fci!(citizen: citizen)
      persist_fcd!(citizen: citizen)
    end

    result = with_tenant(membership) do
      described_class.evaluate(
        expression: expression_for("V_CAD"),
        context: Indicators::DslV1::Context.new(citizen: citizen)
      )
    end

    expect(result.meets_numerator).to be(true)
  end

  it "computes team score from citizens in denominator" do
    citizens = with_tenant(membership) do
      complete = create(:citizen, municipality: municipality, health_facility: facility, care_team: team, birth_date: Date.new(1980, 1, 1), full_name: "A")
      incomplete = create(:citizen, municipality: municipality, health_facility: facility, care_team: team, birth_date: nil, full_name: "B")
      persist_fci!(citizen: complete)
      persist_fcd!(citizen: complete)
      [ complete, incomplete ]
    end

    score = with_tenant(membership) do
      described_class.team_score(
        expression: expression_for("V_CAD"),
        citizens: Citizen.where(id: citizens.map(&:id)),
        quadrimester: "2026-Q1",
        care_team_id: team.id
      )
    end

    expect(score).to eq(50.0)
  end

  it "scores V_CAD team score from COM only when ATU fails" do
    citizens = with_tenant(membership) do
      citizen = create(
        :citizen,
        municipality: municipality,
        health_facility: facility,
        care_team: team,
        birth_date: Date.new(1980, 1, 1),
        full_name: "COM only"
      )
      persist_fcd!(citizen: citizen)
      persist_fci!(citizen: citizen, encounter_at: 3.years.ago)
      [ citizen ]
    end

    score = with_tenant(membership) do
      described_class.team_score(
        expression: expression_for("V_CAD"),
        citizens: Citizen.where(id: citizens.map(&:id)),
        quadrimester: "2026-Q1",
        care_team_id: team.id
      )
    end

    expect(score).to eq(100.0)
  end

  it "scores C1 programmed attendance from completed appointments only" do
    quadrimester = Indicators::Quadrimester.current
    range = Indicators::Quadrimester.range_for(quadrimester)
    scheduled_at = range.begin + 10.days

    service_type = with_tenant(membership) do
      AppointmentServiceType.create!(municipality: municipality, code: "medical_consultation", name: "Consulta")
    end
    room = with_tenant(membership) do
      ConsultationRoom.create!(municipality: municipality, health_facility: facility, name: "Sala 1", room_kind: "general")
    end
    citizen = with_tenant(membership) do
      create(:citizen, municipality: municipality, health_facility: facility, care_team: team)
    end

    with_tenant(membership) do
      [
        { kind: "scheduled", status: "completed" },
        { kind: "walk_in", status: "completed" },
        { kind: "scheduled", status: "checked_in" },
        { kind: "scheduled", status: "cancelled" }
      ].each_with_index do |attrs, index|
        Appointment.create!(
          municipality: municipality,
          health_facility: facility,
          consultation_room: room,
          appointment_service_type: service_type,
          citizen: citizen,
          care_team: team,
          scheduled_at: scheduled_at + index.hours,
          status: attrs.fetch(:status),
          kind: attrs.fetch(:kind),
          channel: "web_reception",
          modality: "presential",
          duration_minutes: 30
        )
      end
    end

    score = with_tenant(membership) do
      described_class.team_score(
        expression: expression_for("C1"),
        citizens: Citizen.where(id: citizen.id),
        quadrimester: quadrimester,
        care_team_id: team.id
      )
    end

    expect(score).to eq(50.0)
  end

  it "computes CVAT team score on MS 0–10 scale" do
    citizens = with_tenant(membership) do
      citizen = create(
        :citizen,
        municipality: municipality,
        health_facility: facility,
        care_team: team,
        birth_date: Date.new(1980, 1, 1),
        full_name: "Complete"
      )
      # FCD outside V_SAT 6m window; FCI satisfies V_CAD_ATU so CVAT = 0.3×100 + 0.7×0 on MS scale.
      persist_fcd!(citizen: citizen, encounter_at: 7.months.ago)
      persist_fci!(citizen: citizen)
      [ citizen ]
    end

    score = with_tenant(membership) do
      described_class.team_score(
        expression: expression_for("CVAT"),
        citizens: Citizen.where(id: citizens.map(&:id)),
        quadrimester: "2026-Q1",
        care_team_id: team.id
      )
    end

    expect(score).to eq(3.0)
  end

  it "raises when linkage aggregate references a missing child rule" do
    citizen = with_tenant(membership) do
      create(:citizen, municipality: municipality, health_facility: facility, care_team: team, birth_date: Date.new(1980, 1, 1))
    end
    expression = {
      "version" => "dsl_v1",
      "team_score_mode" => "linkage_aggregate",
      "linkage_components" => [ { "code" => "NO_SUCH_INDICATOR", "weight" => 1.0 } ]
    }

    expect do
      with_tenant(membership) do
        described_class.team_score(
          expression: expression,
          citizens: Citizen.where(id: citizen.id),
          quadrimester: "2026-Q1",
          care_team_id: team.id
        )
      end
    end.to raise_error(ArgumentError, /missing dsl_v1 rule/)
  end

  it "renormalizes linkage aggregate when configured weights sum below 1.0" do
    citizens = with_tenant(membership) do
      citizen = create(
        :citizen,
        municipality: municipality,
        health_facility: facility,
        care_team: team,
        birth_date: Date.new(1980, 1, 1),
        full_name: "Complete"
      )
      persist_fcd!(citizen: citizen)
      persist_fci!(citizen: citizen)
      [ citizen ]
    end

    expression = {
      "version" => "dsl_v1",
      "team_score_mode" => "linkage_aggregate",
      "linkage_components" => [ { "code" => "V_CAD", "weight" => 0.5 } ]
    }

    score = with_tenant(membership) do
      described_class.team_score(
        expression: expression,
        citizens: Citizen.where(id: citizens.map(&:id)),
        quadrimester: "2026-Q1",
        care_team_id: team.id
      )
    end

    expect(score).to eq(100.0)
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

    result = with_tenant(membership) do
      described_class.evaluate(
        expression: expression_for("C2", rule_code: "A"),
        context: Indicators::DslV1::Context.new(citizen: citizen, reference_date: Date.current)
      )
    end

    expect(result.in_denominator).to be(false)
  end

  it "scores C2-A when first consult occurred within 30 days of birth regardless of reference date" do
    birth_date = Date.current - 20.months
    citizen = with_tenant(membership) do
      create(
        :citizen,
        municipality: municipality,
        health_facility: facility,
        care_team: team,
        birth_date: birth_date,
        full_name: "Criança 1ª consulta"
      )
    end

    with_tenant(membership) do
      persist_clinical_record!(
        citizen: citizen,
        record_type: "FAI",
        payload_json: {},
        encounter_at: birth_date + 20.days
      )
    end

    result = with_tenant(membership) do
      described_class.evaluate(
        expression: expression_for("C2", rule_code: "A"),
        context: Indicators::DslV1::Context.new(citizen: citizen, reference_date: Date.current)
      )
    end

    expect(result.in_denominator).to be(true)
    expect(result.meets_numerator).to be(true)
  end

  it "scores C3-A when first prenatal consult is within 12 weeks of DUM" do
    reference_date = Date.current
    dum_date = reference_date - 3.months
    consult_date = dum_date + 8.weeks
    citizen = with_tenant(membership) do
      create(
        :citizen,
        municipality: municipality,
        health_facility: facility,
        care_team: team,
        birth_date: Date.new(1995, 3, 15),
        full_name: "Gestante Test",
        sex: "female"
      )
    end

    with_tenant(membership) do
      persist_fci_pregnant!(citizen: citizen, encounter_at: reference_date - 1.month)
      persist_clinical_record!(
        citizen: citizen,
        record_type: "FAI",
        payload_json: { "dumDaGestante" => dum_date.iso8601 },
        encounter_at: consult_date
      )
    end

    result = with_tenant(membership) do
      described_class.evaluate(
        expression: expression_for("C3", rule_code: "A"),
        context: Indicators::DslV1::Context.new(citizen: citizen, reference_date: reference_date)
      )
    end

    expect(result.in_denominator).to be(true)
    expect(result.meets_numerator).to be(true)
  end

  it "does not score C3-A when prenatal consult is after 12 weeks from DUM" do
    reference_date = Date.current
    dum_date = reference_date - 3.months
    consult_date = dum_date + 14.weeks
    citizen = with_tenant(membership) do
      create(
        :citizen,
        municipality: municipality,
        health_facility: facility,
        care_team: team,
        birth_date: Date.new(1995, 3, 15),
        full_name: "Gestante Tardia",
        sex: "female"
      )
    end

    with_tenant(membership) do
      persist_fci_pregnant!(citizen: citizen, encounter_at: reference_date - 1.month)
      persist_clinical_record!(
        citizen: citizen,
        record_type: "FAI",
        payload_json: { "dumDaGestante" => dum_date.iso8601 },
        encounter_at: consult_date
      )
    end

    result = with_tenant(membership) do
      described_class.evaluate(
        expression: expression_for("C3", rule_code: "A"),
        context: Indicators::DslV1::Context.new(citizen: citizen, reference_date: reference_date)
      )
    end

    expect(result.in_denominator).to be(true)
    expect(result.meets_numerator).to be(false)
  end

  it "scores C3-A when clinical_record.encounter_at is nil but linked encounter has date" do
    reference_date = Date.current
    dum_date = reference_date - 2.months
    citizen = with_tenant(membership) do
      create(
        :citizen,
        municipality: municipality,
        health_facility: facility,
        care_team: team,
        birth_date: Date.new(1995, 3, 15),
        full_name: "Gestante Sem Data Record",
        sex: "female"
      )
    end

    with_tenant(membership) do
      persist_fci_pregnant!(citizen: citizen, encounter_at: reference_date - 1.month)
      record = persist_clinical_record!(
        citizen: citizen,
        record_type: "FAI",
        payload_json: { "dumDaGestante" => dum_date.iso8601 },
        encounter_at: dum_date + 8.weeks
      )
      record.update_column(:encounter_at, nil)
    end

    result = with_tenant(membership) do
      described_class.evaluate(
        expression: expression_for("C3", rule_code: "A"),
        context: Indicators::DslV1::Context.new(citizen: citizen, reference_date: reference_date)
      )
    end

    expect(result.in_denominator).to be(true)
    expect(result.meets_numerator).to be(true)
  end

  it "does not score C3-A when no effective encounter date exists" do
    reference_date = Date.current
    dum_date = reference_date - 2.months
    citizen = with_tenant(membership) do
      create(
        :citizen,
        municipality: municipality,
        health_facility: facility,
        care_team: team,
        birth_date: Date.new(1995, 3, 15),
        full_name: "Gestante Sem Data",
        sex: "female"
      )
    end

    with_tenant(membership) do
      persist_fci_pregnant!(citizen: citizen, encounter_at: reference_date - 1.month)
      record = persist_clinical_record!(
        citizen: citizen,
        record_type: "FAI",
        payload_json: { "dumDaGestante" => dum_date.iso8601 },
        encounter_at: reference_date - 1.day
      )
      record.update_column(:encounter_at, nil)
      Encounter.where(clinical_record_id: record.id).delete_all
    end

    result = with_tenant(membership) do
      described_class.evaluate(
        expression: expression_for("C3", rule_code: "A"),
        context: Indicators::DslV1::Context.new(citizen: citizen, reference_date: reference_date)
      )
    end

    expect(result.in_denominator).to be(true)
    expect(result.meets_numerator).to be(false)
  end

  it "scores C3-A when 1ª consult is DUM-anchored beyond a 9-month reference window" do
    reference_date = Date.current
    dum_date = reference_date - 11.months
    consult_date = dum_date + 8.weeks
    citizen = with_tenant(membership) do
      create(
        :citizen,
        municipality: municipality,
        health_facility: facility,
        care_team: team,
        birth_date: Date.new(1995, 3, 15),
        full_name: "Gestante Janela Longa",
        sex: "female"
      )
    end

    with_tenant(membership) do
      persist_fci_pregnant!(citizen: citizen, encounter_at: reference_date - 1.month)
      persist_clinical_record!(
        citizen: citizen,
        record_type: "FAI",
        payload_json: { "dumDaGestante" => dum_date.iso8601 },
        encounter_at: consult_date
      )
    end

    result = with_tenant(membership) do
      described_class.evaluate(
        expression: expression_for("C3", rule_code: "A"),
        context: Indicators::DslV1::Context.new(citizen: citizen, reference_date: reference_date)
      )
    end

    expect(result.in_denominator).to be(true)
    expect(result.meets_numerator).to be(true)
  end

  it "scores C3-A when DUM is within the 15-month lookback window" do
    reference_date = Date.current
    dum_date = reference_date - 14.months
    consult_date = dum_date + 8.weeks
    citizen = with_tenant(membership) do
      create(
        :citizen,
        municipality: municipality,
        health_facility: facility,
        care_team: team,
        birth_date: Date.new(1995, 3, 15),
        full_name: "Gestante Lookback 15m",
        sex: "female"
      )
    end

    with_tenant(membership) do
      persist_fci_pregnant!(citizen: citizen, encounter_at: reference_date - 1.month)
      persist_clinical_record!(
        citizen: citizen,
        record_type: "FAI",
        payload_json: { "dumDaGestante" => dum_date.iso8601 },
        encounter_at: consult_date
      )
    end

    result = with_tenant(membership) do
      described_class.evaluate(
        expression: expression_for("C3", rule_code: "A"),
        context: Indicators::DslV1::Context.new(citizen: citizen, reference_date: reference_date)
      )
    end

    expect(result.in_denominator).to be(true)
    expect(result.meets_numerator).to be(true)
  end

  it "scores C2-E when FV vaccination record exists" do
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
        record_type: "FV",
        payload_json: { "vacinas" => [ { "imunobiologico" => "BCG" } ] },
        encounter_at: 1.month.ago
      )
    end

    result = with_tenant(membership) do
      described_class.evaluate(
        expression: expression_for("C2", rule_code: "E"),
        context: Indicators::DslV1::Context.new(citizen: citizen, reference_date: Date.current)
      )
    end

    expect(result.in_denominator).to be(true)
    expect(result.meets_numerator).to be(true)
  end

  it "scores C2-E when clinical_record.encounter_at is nil but linked encounter has date" do
    citizen = with_tenant(membership) do
      create(
        :citizen,
        municipality: municipality,
        health_facility: facility,
        care_team: team,
        birth_date: Date.current - 18.months,
        full_name: "Criança FV Sem Data Record"
      )
    end

    with_tenant(membership) do
      record = persist_clinical_record!(
        citizen: citizen,
        record_type: "FV",
        payload_json: { "vacinas" => [ { "imunobiologico" => "BCG" } ] },
        encounter_at: 1.month.ago
      )
      record.update_column(:encounter_at, nil)
    end

    result = with_tenant(membership) do
      described_class.evaluate(
        expression: expression_for("C2", rule_code: "E"),
        context: Indicators::DslV1::Context.new(citizen: citizen, reference_date: Date.current)
      )
    end

    expect(result.in_denominator).to be(true)
    expect(result.meets_numerator).to be(true)
  end

  it "does not score C2-E when no effective encounter date exists" do
    citizen = with_tenant(membership) do
      create(
        :citizen,
        municipality: municipality,
        health_facility: facility,
        care_team: team,
        birth_date: Date.current - 18.months,
        full_name: "Criança FV Sem Data"
      )
    end

    with_tenant(membership) do
      record = persist_clinical_record!(
        citizen: citizen,
        record_type: "FV",
        payload_json: { "vacinas" => [ { "imunobiologico" => "BCG" } ] },
        encounter_at: 1.month.ago
      )
      record.update_column(:encounter_at, nil)
      Encounter.where(clinical_record_id: record.id).delete_all
    end

    result = with_tenant(membership) do
      described_class.evaluate(
        expression: expression_for("C2", rule_code: "E"),
        context: Indicators::DslV1::Context.new(citizen: citizen, reference_date: Date.current)
      )
    end

    expect(result.in_denominator).to be(true)
    expect(result.meets_numerator).to be(false)
  end

  it "uses newer linked encounter when clinical_record.encounter_at is stale" do
    citizen = with_tenant(membership) do
      create(
        :citizen,
        municipality: municipality,
        health_facility: facility,
        care_team: team,
        birth_date: Date.new(1970, 1, 1),
        full_name: "Diabético Consulta Recente"
      )
    end

    with_tenant(membership) do
      persist_fci_diabetic!(citizen: citizen, encounter_at: 1.month.ago)
      record = persist_clinical_record!(
        citizen: citizen,
        record_type: "FAI",
        payload_json: {},
        encounter_at: 1.month.ago
      )
      record.update_column(:encounter_at, 2.years.ago)
    end

    result = with_tenant(membership) do
      described_class.evaluate(
        expression: expression_for("C4", rule_code: "A"),
        context: Indicators::DslV1::Context.new(citizen: citizen, reference_date: Date.current)
      )
    end

    expect(result.in_denominator).to be(true)
    expect(result.meets_numerator).to be(true)
  end

  it "scores C4-D anthropometry when clinical_record.encounter_at is nil but linked encounter has date" do
    citizen = with_tenant(membership) do
      create(
        :citizen,
        municipality: municipality,
        health_facility: facility,
        care_team: team,
        birth_date: Date.new(1970, 1, 1),
        full_name: "Diabético Antropometria"
      )
    end

    with_tenant(membership) do
      persist_fci_diabetic!(citizen: citizen, encounter_at: 1.month.ago)
      record = persist_clinical_record!(
        citizen: citizen,
        record_type: "FAI",
        payload_json: {
          "medicoes" => { "peso" => 80, "altura" => 170 }
        },
        encounter_at: 1.month.ago
      )
      record.update_column(:encounter_at, nil)
    end

    result = with_tenant(membership) do
      described_class.evaluate(
        expression: expression_for("C4", rule_code: "D"),
        context: Indicators::DslV1::Context.new(citizen: citizen, reference_date: Date.current)
      )
    end

    expect(result.in_denominator).to be(true)
    expect(result.meets_numerator).to be(true)
  end

  it "does not reuse encounter_at cache across citizens on the same team" do
    reference_date = Date.current
    shared_cache = {}
    citizens = with_tenant(membership) do
      2.times.map do |i|
        create(
          :citizen,
          municipality: municipality,
          health_facility: facility,
          care_team: team,
          birth_date: Date.new(1995, 3, 15),
          full_name: "Gestante Cache #{i}",
          sex: "female"
        )
      end
    end

    citizens.each_with_index do |citizen, index|
      dum_date = reference_date - (2 + index).months
      with_tenant(membership) do
        persist_fci_pregnant!(citizen: citizen, encounter_at: reference_date - 1.month)
        record = persist_clinical_record!(
          citizen: citizen,
          record_type: "FAI",
          payload_json: { "dumDaGestante" => dum_date.iso8601 },
          encounter_at: dum_date + 8.weeks
        )
        record.update_column(:encounter_at, nil)
      end
    end

    results = citizens.map do |citizen|
      with_tenant(membership) do
        described_class.evaluate(
          expression: expression_for("C3", rule_code: "A"),
          context: Indicators::DslV1::Context.new(
            citizen: citizen,
            reference_date: reference_date,
            cache: shared_cache
          )
        )
      end
    end

    expect(results).to all(have_attributes(in_denominator: true, meets_numerator: true))
  end

  it "scores C2-D when ACS visits meet first-30d and second-6m schedule" do
    birth_date = Date.current - 4.months
    citizen = with_tenant(membership) do
      create(
        :citizen,
        municipality: municipality,
        health_facility: facility,
        care_team: team,
        birth_date: birth_date,
        full_name: "Criança ACS"
      )
    end

    with_tenant(membership) do
      persist_clinical_record!(
        citizen: citizen,
        record_type: "FVD",
        payload_json: {},
        encounter_at: birth_date + 15.days
      )
      persist_clinical_record!(
        citizen: citizen,
        record_type: "FVD",
        payload_json: {},
        encounter_at: birth_date + 3.months
      )
    end

    result = with_tenant(membership) do
      described_class.evaluate(
        expression: expression_for("C2", rule_code: "D"),
        context: Indicators::DslV1::Context.new(citizen: citizen, reference_date: Date.current)
      )
    end

    expect(result.in_denominator).to be(true)
    expect(result.meets_numerator).to be(true)
  end

  it "does not score C2-D when the first ACS visit is after 30 days" do
    birth_date = Date.current - 4.months
    citizen = with_tenant(membership) do
      create(
        :citizen,
        municipality: municipality,
        health_facility: facility,
        care_team: team,
        birth_date: birth_date,
        full_name: "Criança ACS tardia"
      )
    end

    with_tenant(membership) do
      persist_clinical_record!(
        citizen: citizen,
        record_type: "FVD",
        payload_json: {},
        encounter_at: birth_date + 45.days
      )
      persist_clinical_record!(
        citizen: citizen,
        record_type: "FVD",
        payload_json: {},
        encounter_at: birth_date + 3.months
      )
    end

    result = with_tenant(membership) do
      described_class.evaluate(
        expression: expression_for("C2", rule_code: "D"),
        context: Indicators::DslV1::Context.new(citizen: citizen, reference_date: Date.current)
      )
    end

    expect(result.in_denominator).to be(true)
    expect(result.meets_numerator).to be(false)
  end

  it "scores C2-D for toddlers when ACS visits occurred in the first 6 months of life" do
    birth_date = Date.current - 20.months
    citizen = with_tenant(membership) do
      create(
        :citizen,
        municipality: municipality,
        health_facility: facility,
        care_team: team,
        birth_date: birth_date,
        full_name: "Criança ACS histórica"
      )
    end

    with_tenant(membership) do
      persist_clinical_record!(
        citizen: citizen,
        record_type: "FVD",
        payload_json: {},
        encounter_at: birth_date + 15.days
      )
      persist_clinical_record!(
        citizen: citizen,
        record_type: "FVD",
        payload_json: {},
        encounter_at: birth_date + 3.months
      )
    end

    result = with_tenant(membership) do
      described_class.evaluate(
        expression: expression_for("C2", rule_code: "D"),
        context: Indicators::DslV1::Context.new(citizen: citizen, reference_date: Date.current)
      )
    end

    expect(result.in_denominator).to be(true)
    expect(result.meets_numerator).to be(true)
  end

  it "scores V_ACOMP when multiple contacts and one attendance exist in 12 months" do
    citizen = with_tenant(membership) do
      create(
        :citizen,
        municipality: municipality,
        health_facility: facility,
        care_team: team,
        birth_date: Date.new(1985, 1, 1),
        full_name: "Acompanhamento Test"
      )
    end

    with_tenant(membership) do
      2.times do |i|
        persist_clinical_record!(
          citizen: citizen,
          record_type: "FVD",
          payload_json: {},
          encounter_at: (2 + i).months.ago
        )
      end
      persist_clinical_record!(
        citizen: citizen,
        record_type: "FAI",
        payload_json: {},
        encounter_at: 1.month.ago
      )
    end

    result = with_tenant(membership) do
      described_class.evaluate(
        expression: expression_for("V_ACOMP"),
        context: Indicators::DslV1::Context.new(citizen: citizen, reference_date: Date.current)
      )
    end

    expect(result.in_denominator).to be(true)
    expect(result.meets_numerator).to be(true)
  end

  it "aggregates C4 team score as good practices percentage" do
    citizens = with_tenant(membership) do
      create_list(:citizen, 2, municipality: municipality, health_facility: facility, care_team: team, birth_date: Date.new(1970, 1, 1))
    end

    score = with_tenant(membership) do
      described_class.good_practices_pct_score(
        indicator_code: "C4",
        citizens: Citizen.where(id: citizens.map(&:id)),
        quadrimester: "2026-Q1",
        care_team_id: team.id
      )
    end

    expect(score).to eq(0.0)
  end

  it "requires team context for good_practices_pct_score" do
    expect do
      described_class.good_practices_pct_score(
        indicator_code: "C4",
        citizens: Citizen.none,
        quadrimester: "2026-Q1"
      )
    end.to raise_error(Indicators::Errors::TeamContextRequiredError)
  end

  it "raises when care_team_id does not exist for good_practices_pct_score" do
    expect do
      described_class.good_practices_pct_score(
        indicator_code: "C4",
        citizens: Citizen.none,
        quadrimester: "2026-Q1",
        care_team_id: 0
      )
    end.to raise_error(Indicators::Errors::UnknownCareTeamError)
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

  it "scores B1 when FAO has first programmed dental consult type" do
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

    with_tenant(membership) do
      persist_clinical_record!(
        citizen: citizen,
        record_type: "FAO",
        payload_json: {
          "atendimentos_odontologicos" => [
            { "tipos_consulta_odonto" => [ 1 ], "cpfCidadao" => citizen.cpf }
          ]
        },
        encounter_at: 2.months.ago
      )
    end

    result = with_tenant(membership) do
      described_class.evaluate(
        expression: expression_for("B1"),
        context: Indicators::DslV1::Context.new(citizen: citizen, reference_date: Date.current)
      )
    end

    expect(result.in_denominator).to be(true)
    expect(result.meets_numerator).to be(true)
  end

  it "computes B3 team score from extraction procedure ratio" do
    esb_team = with_tenant(membership) do
      create(:care_team, :esb, municipality: municipality, health_facility: facility)
    end
    citizens = with_tenant(membership) do
      create_list(:citizen, 2, municipality: municipality, health_facility: facility, care_team: esb_team)
    end

    with_tenant(membership) do
      citizens.each do |citizen|
        persist_clinical_record!(
          citizen: citizen,
          record_type: "FAO",
          care_team: esb_team,
          payload_json: {
            "atendimentos_odontologicos" => [
              {
                "procedimentos_realizados" => [
                  { "co_ms_procedimento" => "0414020070", "quantidade" => 1 },
                  { "co_ms_procedimento" => "0301010066", "quantidade" => 1 }
                ]
              }
            ]
          },
          encounter_at: 1.month.ago
        )
      end
    end

    score = with_tenant(membership) do
      described_class.team_score(
        expression: expression_for("B3"),
        citizens: Citizen.where(id: citizens.map(&:id)),
        quadrimester: "2026-Q1",
        care_team_id: esb_team.id
      )
    end

    expect(score).to eq(50.0)
  end

  it "scores M2 when FAC has interprofessional activity" do
    emulti_team = with_tenant(membership) do
      create(:care_team, :emulti, municipality: municipality, health_facility: facility)
    end
    citizen = with_tenant(membership) do
      create(
        :citizen,
        municipality: municipality,
        health_facility: facility,
        care_team: emulti_team,
        birth_date: Date.new(1985, 8, 2),
        full_name: "eMulti Test"
      )
    end

    with_tenant(membership) do
      persist_clinical_record!(
        citizen: citizen,
        record_type: "FAC",
        payload_json: {
          "profissionais" => [
            { "codigo_cbo2002" => "223505" },
            { "codigo_cbo2002" => "251510" }
          ],
          "atividade_tipo" => 4
        },
        encounter_at: 1.month.ago
      )
    end

    result = with_tenant(membership) do
      described_class.evaluate(
        expression: expression_for("M2"),
        context: Indicators::DslV1::Context.new(citizen: citizen, reference_date: Date.current)
      )
    end

    expect(result.in_denominator).to be(true)
    expect(result.meets_numerator).to be(true)
  end
end
