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

  def persist_fci!(citizen:, care_team: team, encounter_at: 1.month.ago, extra_payload: {})
    persist_clinical_record!(
      citizen: citizen,
      record_type: "FCI",
      care_team: care_team,
      payload_json: {
        "identificacaoUsuarioCidadao" => {
          "nome" => citizen.full_name,
          "dataNascimento" => citizen.birth_date&.iso8601,
          "cpfCidadao" => citizen.cpf,
          "microArea" => "01"
        },
        "dataAtualizacao" => encounter_at.iso8601
      }.deep_merge(extra_payload.stringify_keys),
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

  def persist_prenatal_fai!(citizen:, dum:, encounter_at:, with_attendance: true, extra_payload: {})
    payload = { "dumDaGestante" => dum.iso8601 }.merge(extra_payload.stringify_keys)
    payload["atendimentos_individuais"] = [ { "tipo" => "consulta" } ] if with_attendance
    persist_clinical_record!(
      citizen: citizen,
      record_type: "FAI",
      payload_json: payload,
      encounter_at: encounter_at
    )
  end

  def evaluate_c3!(citizen:, rule_code:, reference_date: Date.current)
    with_tenant(membership) do
      described_class.evaluate(
        expression: expression_for("C3", rule_code: rule_code),
        context: Indicators::DslV1::Context.new(citizen: citizen, reference_date: reference_date)
      )
    end
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
        payload_json: {
          "dumDaGestante" => dum_date.iso8601,
          "atendimentos_individuais" => [ { "tipo" => "consulta" } ]
        },
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
        payload_json: {
          "dumDaGestante" => dum_date.iso8601,
          "atendimentos_individuais" => [ { "tipo" => "consulta" } ]
        },
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
        payload_json: {
          "dumDaGestante" => dum_date.iso8601,
          "atendimentos_individuais" => [ { "tipo" => "consulta" } ]
        },
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
        payload_json: {
          "dumDaGestante" => dum_date.iso8601,
          "atendimentos_individuais" => [ { "tipo" => "consulta" } ]
        },
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
        payload_json: {
          "dumDaGestante" => dum_date.iso8601,
          "atendimentos_individuais" => [ { "tipo" => "consulta" } ]
        },
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
        payload_json: {
          "dumDaGestante" => dum_date.iso8601,
          "atendimentos_individuais" => [ { "tipo" => "consulta" } ]
        },
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

  it "does not score C3-A when FAI after DUM lacks individual attendances" do
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
        full_name: "Gestante Sem Atendimento",
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

  it "scores C3-B with seven prenatal consults during gestation" do
    reference_date = Date.new(2026, 5, 30)
    dum = reference_date - 6.months
    citizen = with_tenant(membership) do
      create(
        :citizen,
        municipality: municipality,
        health_facility: facility,
        care_team: team,
        birth_date: Date.new(1995, 3, 15),
        full_name: "Gestante Sete Consultas",
        sex: "female"
      )
    end

    with_tenant(membership) do
      persist_fci_pregnant!(citizen: citizen, encounter_at: reference_date - 2.months)
      [ 4, 8, 12, 16, 20, 24, 28 ].each do |weeks|
        persist_prenatal_fai!(citizen: citizen, dum: dum, encounter_at: dum + weeks.weeks)
      end
    end

    result = evaluate_c3!(citizen: citizen, rule_code: "B", reference_date: reference_date)

    expect(result.in_denominator).to be(true)
    expect(result.meets_numerator).to be(true)
  end

  it "does not score C3-B when only six consults occur during gestation" do
    reference_date = Date.new(2026, 5, 30)
    dum = reference_date - 6.months
    citizen = with_tenant(membership) do
      create(
        :citizen,
        municipality: municipality,
        health_facility: facility,
        care_team: team,
        birth_date: Date.new(1995, 3, 15),
        full_name: "Gestante Seis Consultas",
        sex: "female"
      )
    end

    with_tenant(membership) do
      persist_fci_pregnant!(citizen: citizen, encounter_at: reference_date - 2.months)
      [ 4, 8, 12, 16, 20, 24 ].each do |weeks|
        persist_prenatal_fai!(citizen: citizen, dum: dum, encounter_at: dum + weeks.weeks)
      end
    end

    result = evaluate_c3!(citizen: citizen, rule_code: "B", reference_date: reference_date)

    expect(result.meets_numerator).to be(false)
  end

  it "does not score C3-B when FAI lacks individual attendances" do
    reference_date = Date.new(2026, 5, 30)
    dum = reference_date - 6.months
    citizen = with_tenant(membership) do
      create(
        :citizen,
        municipality: municipality,
        health_facility: facility,
        care_team: team,
        birth_date: Date.new(1995, 3, 15),
        full_name: "Gestante Consulta Sem Atendimento",
        sex: "female"
      )
    end

    with_tenant(membership) do
      persist_fci_pregnant!(citizen: citizen, encounter_at: reference_date - 2.months)
      [ 4, 8, 12, 16, 20, 24, 28 ].each do |weeks|
        persist_prenatal_fai!(citizen: citizen, dum: dum, encounter_at: dum + weeks.weeks, with_attendance: false)
      end
    end

    result = evaluate_c3!(citizen: citizen, rule_code: "B", reference_date: reference_date)

    expect(result.meets_numerator).to be(false)
  end

  it "does not count post-delivery consults toward C3-B" do
    reference_date = Date.new(2026, 5, 30)
    dum = reference_date - 10.months
    delivery = dum + 280.days
    citizen = with_tenant(membership) do
      create(
        :citizen,
        municipality: municipality,
        health_facility: facility,
        care_team: team,
        birth_date: Date.new(1995, 3, 15),
        full_name: "Gestante Pos Parto Consulta",
        sex: "female"
      )
    end

    with_tenant(membership) do
      persist_fci_pregnant!(citizen: citizen, encounter_at: reference_date - 9.months)
      [ 4, 8, 12, 16, 20, 24 ].each do |weeks|
        persist_prenatal_fai!(citizen: citizen, dum: dum, encounter_at: dum + weeks.weeks)
      end
      persist_prenatal_fai!(citizen: citizen, dum: dum, encounter_at: delivery + 3.days, extra_payload: { "dataParto" => delivery.iso8601 })
      persist_prenatal_fai!(citizen: citizen, dum: dum, encounter_at: delivery + 10.days)
    end

    result = evaluate_c3!(citizen: citizen, rule_code: "B", reference_date: reference_date)

    expect(result.meets_numerator).to be(false)
  end

  it "scores C3-C with seven blood pressure measurements during gestation" do
    reference_date = Date.new(2026, 5, 30)
    dum = reference_date - 6.months
    citizen = with_tenant(membership) do
      create(
        :citizen,
        municipality: municipality,
        health_facility: facility,
        care_team: team,
        birth_date: Date.new(1995, 3, 15),
        full_name: "Gestante PA",
        sex: "female"
      )
    end

    with_tenant(membership) do
      persist_fci_pregnant!(citizen: citizen, encounter_at: reference_date - 2.months)
      persist_prenatal_fai!(citizen: citizen, dum: dum, encounter_at: dum + 8.weeks)
      [ 10, 14, 18, 22, 26, 30, 34 ].each do |weeks|
        persist_clinical_record!(
          citizen: citizen,
          record_type: "FAI",
          payload_json: {
            "medicoes" => { "pressaoArterialSistolica" => 120, "pressaoArterialDiastolica" => 80 }
          },
          encounter_at: dum + weeks.weeks
        )
      end
    end

    result = evaluate_c3!(citizen: citizen, rule_code: "C", reference_date: reference_date)

    expect(result.meets_numerator).to be(true)
  end

  it "scores C3-D with seven anthropometry records during gestation" do
    reference_date = Date.new(2026, 5, 30)
    dum = reference_date - 6.months
    citizen = with_tenant(membership) do
      create(
        :citizen,
        municipality: municipality,
        health_facility: facility,
        care_team: team,
        birth_date: Date.new(1995, 3, 15),
        full_name: "Gestante Antropometria",
        sex: "female"
      )
    end

    with_tenant(membership) do
      persist_fci_pregnant!(citizen: citizen, encounter_at: reference_date - 2.months)
      persist_prenatal_fai!(citizen: citizen, dum: dum, encounter_at: dum + 8.weeks)
      [ 10, 14, 18, 22, 26, 30, 34 ].each do |weeks|
        persist_clinical_record!(
          citizen: citizen,
          record_type: "FAI",
          payload_json: { "medicoes" => { "peso" => 70, "altura" => 165 } },
          encounter_at: dum + weeks.weeks
        )
      end
    end

    result = evaluate_c3!(citizen: citizen, rule_code: "D", reference_date: reference_date)

    expect(result.meets_numerator).to be(true)
  end

  it "scores C3-E with three ACS visits after the first prenatal consult" do
    reference_date = Date.new(2026, 5, 30)
    dum = reference_date - 6.months
    first_consult = dum + 8.weeks
    citizen = with_tenant(membership) do
      create(
        :citizen,
        municipality: municipality,
        health_facility: facility,
        care_team: team,
        birth_date: Date.new(1995, 3, 15),
        full_name: "Gestante Visitas ACS",
        sex: "female"
      )
    end

    with_tenant(membership) do
      persist_fci_pregnant!(citizen: citizen, encounter_at: reference_date - 2.months)
      persist_prenatal_fai!(citizen: citizen, dum: dum, encounter_at: first_consult)
      [ 12, 16, 20 ].each do |weeks|
        persist_clinical_record!(
          citizen: citizen,
          record_type: "FVD",
          payload_json: { "motivosVisita" => [ { "codigo" => 1 } ] },
          encounter_at: dum + weeks.weeks
        )
      end
    end

    result = evaluate_c3!(citizen: citizen, rule_code: "E", reference_date: reference_date)

    expect(result.meets_numerator).to be(true)
  end

  it "does not score C3-E when ACS visits occur before the first prenatal consult" do
    reference_date = Date.new(2026, 5, 30)
    dum = reference_date - 6.months
    first_consult = dum + 8.weeks
    citizen = with_tenant(membership) do
      create(
        :citizen,
        municipality: municipality,
        health_facility: facility,
        care_team: team,
        birth_date: Date.new(1995, 3, 15),
        full_name: "Gestante Visitas Antes",
        sex: "female"
      )
    end

    with_tenant(membership) do
      persist_fci_pregnant!(citizen: citizen, encounter_at: reference_date - 2.months)
      [ 4, 5, 6 ].each do |weeks|
        persist_clinical_record!(
          citizen: citizen,
          record_type: "FVD",
          payload_json: { "motivosVisita" => [ { "codigo" => 1 } ] },
          encounter_at: dum + weeks.weeks
        )
      end
      persist_prenatal_fai!(citizen: citizen, dum: dum, encounter_at: first_consult)
    end

    result = evaluate_c3!(citizen: citizen, rule_code: "E", reference_date: reference_date)

    expect(result.meets_numerator).to be(false)
  end

  it "does not score C3-C when only six blood pressure measurements occur during gestation" do
    reference_date = Date.new(2026, 5, 30)
    dum = reference_date - 6.months
    citizen = with_tenant(membership) do
      create(
        :citizen,
        municipality: municipality,
        health_facility: facility,
        care_team: team,
        birth_date: Date.new(1995, 3, 15),
        full_name: "Gestante PA Insuficiente",
        sex: "female"
      )
    end

    with_tenant(membership) do
      persist_fci_pregnant!(citizen: citizen, encounter_at: reference_date - 2.months)
      persist_prenatal_fai!(citizen: citizen, dum: dum, encounter_at: dum + 8.weeks)
      [ 10, 14, 18, 22, 26, 30 ].each do |weeks|
        persist_clinical_record!(
          citizen: citizen,
          record_type: "FAI",
          payload_json: {
            "medicoes" => { "pressaoArterialSistolica" => 120, "pressaoArterialDiastolica" => 80 }
          },
          encounter_at: dum + weeks.weeks
        )
      end
    end

    result = evaluate_c3!(citizen: citizen, rule_code: "C", reference_date: reference_date)

    expect(result.meets_numerator).to be(false)
  end

  it "does not score C3-D when only six anthropometry records occur during gestation" do
    reference_date = Date.new(2026, 5, 30)
    dum = reference_date - 6.months
    citizen = with_tenant(membership) do
      create(
        :citizen,
        municipality: municipality,
        health_facility: facility,
        care_team: team,
        birth_date: Date.new(1995, 3, 15),
        full_name: "Gestante Antropometria Insuficiente",
        sex: "female"
      )
    end

    with_tenant(membership) do
      persist_fci_pregnant!(citizen: citizen, encounter_at: reference_date - 2.months)
      persist_prenatal_fai!(citizen: citizen, dum: dum, encounter_at: dum + 8.weeks)
      [ 10, 14, 18, 22, 26, 30 ].each do |weeks|
        persist_clinical_record!(
          citizen: citizen,
          record_type: "FAI",
          payload_json: { "medicoes" => { "peso" => 70, "altura" => 165 } },
          encounter_at: dum + weeks.weeks
        )
      end
    end

    result = evaluate_c3!(citizen: citizen, rule_code: "D", reference_date: reference_date)

    expect(result.meets_numerator).to be(false)
  end

  it "does not score C3-E when only two ACS visits occur after the first prenatal consult" do
    reference_date = Date.new(2026, 5, 30)
    dum = reference_date - 6.months
    first_consult = dum + 8.weeks
    citizen = with_tenant(membership) do
      create(
        :citizen,
        municipality: municipality,
        health_facility: facility,
        care_team: team,
        birth_date: Date.new(1995, 3, 15),
        full_name: "Gestante Duas Visitas ACS",
        sex: "female"
      )
    end

    with_tenant(membership) do
      persist_fci_pregnant!(citizen: citizen, encounter_at: reference_date - 2.months)
      persist_prenatal_fai!(citizen: citizen, dum: dum, encounter_at: first_consult)
      [ 12, 16 ].each do |weeks|
        persist_clinical_record!(
          citizen: citizen,
          record_type: "FVD",
          payload_json: { "motivosVisita" => [ { "codigo" => 1 } ] },
          encounter_at: dum + weeks.weeks
        )
      end
    end

    result = evaluate_c3!(citizen: citizen, rule_code: "E", reference_date: reference_date)

    expect(result.meets_numerator).to be(false)
  end

  it "scores C3-E when first prenatal consult is after 12 weeks but three ACS visits follow" do
    reference_date = Date.new(2026, 5, 30)
    dum = reference_date - 6.months
    first_consult = dum + 14.weeks
    citizen = with_tenant(membership) do
      create(
        :citizen,
        municipality: municipality,
        health_facility: facility,
        care_team: team,
        birth_date: Date.new(1995, 3, 15),
        full_name: "Gestante E Sem Teto A",
        sex: "female"
      )
    end

    with_tenant(membership) do
      persist_fci_pregnant!(citizen: citizen, encounter_at: reference_date - 2.months)
      persist_prenatal_fai!(citizen: citizen, dum: dum, encounter_at: first_consult)
      [ 16, 20, 24 ].each do |weeks|
        persist_clinical_record!(
          citizen: citizen,
          record_type: "FVD",
          payload_json: { "motivosVisita" => [ { "codigo" => 1 } ] },
          encounter_at: dum + weeks.weeks
        )
      end
    end

    a_result = evaluate_c3!(citizen: citizen, rule_code: "A", reference_date: reference_date)
    e_result = evaluate_c3!(citizen: citizen, rule_code: "E", reference_date: reference_date)

    expect(a_result.meets_numerator).to be(false)
    expect(e_result.meets_numerator).to be(true)
  end

  it "scores C3-E when ACS visit occurs on the same day as the first prenatal consult" do
    reference_date = Date.new(2026, 5, 30)
    dum = reference_date - 6.months
    first_consult = dum + 8.weeks
    citizen = with_tenant(membership) do
      create(
        :citizen,
        municipality: municipality,
        health_facility: facility,
        care_team: team,
        birth_date: Date.new(1995, 3, 15),
        full_name: "Gestante Visita Mesmo Dia",
        sex: "female"
      )
    end

    with_tenant(membership) do
      persist_fci_pregnant!(citizen: citizen, encounter_at: reference_date - 2.months)
      persist_prenatal_fai!(citizen: citizen, dum: dum, encounter_at: first_consult)
      persist_clinical_record!(
        citizen: citizen,
        record_type: "FVD",
        payload_json: { "motivosVisita" => [ { "codigo" => 1 } ] },
        encounter_at: first_consult
      )
      [ 12, 16 ].each do |weeks|
        persist_clinical_record!(
          citizen: citizen,
          record_type: "FVD",
          payload_json: { "motivosVisita" => [ { "codigo" => 1 } ] },
          encounter_at: dum + weeks.weeks
        )
      end
    end

    result = evaluate_c3!(citizen: citizen, rule_code: "E", reference_date: reference_date)

    expect(result.meets_numerator).to be(true)
  end

  it "scores C3-E when visit reasons are nested under visitasDomiciliares" do
    reference_date = Date.new(2026, 5, 30)
    dum = reference_date - 6.months
    first_consult = dum + 8.weeks
    citizen = with_tenant(membership) do
      create(
        :citizen,
        municipality: municipality,
        health_facility: facility,
        care_team: team,
        birth_date: Date.new(1995, 3, 15),
        full_name: "Gestante FVD Nested",
        sex: "female"
      )
    end

    with_tenant(membership) do
      persist_fci_pregnant!(citizen: citizen, encounter_at: reference_date - 2.months)
      persist_prenatal_fai!(citizen: citizen, dum: dum, encounter_at: first_consult)
      [ 12, 16, 20 ].each do |weeks|
        persist_clinical_record!(
          citizen: citizen,
          record_type: "FVD",
          payload_json: {
            "visitasDomiciliares" => [ { "motivosVisita" => [ { "codigo" => 1 } ] } ]
          },
          encounter_at: dum + weeks.weeks
        )
      end
    end

    result = evaluate_c3!(citizen: citizen, rule_code: "E", reference_date: reference_date)

    expect(result.meets_numerator).to be(true)
  end

  it "does not treat postpartum FAI as the first prenatal consult for C3-E" do
    reference_date = Date.new(2026, 5, 30)
    dum = reference_date - 10.months
    delivery = dum + 280.days
    first_consult = dum + 8.weeks
    citizen = with_tenant(membership) do
      create(
        :citizen,
        municipality: municipality,
        health_facility: facility,
        care_team: team,
        birth_date: Date.new(1995, 3, 15),
        full_name: "Gestante E Puerperio Piso",
        sex: "female"
      )
    end

    with_tenant(membership) do
      persist_fci_pregnant!(citizen: citizen, encounter_at: reference_date - 9.months)
      persist_prenatal_fai!(citizen: citizen, dum: dum, encounter_at: first_consult)
      persist_clinical_record!(
        citizen: citizen,
        record_type: "FAI",
        payload_json: {
          "dumDaGestante" => dum.iso8601,
          "dataParto" => delivery.iso8601,
          "atendimentos_individuais" => [ { "tipo" => "consulta" } ]
        },
        encounter_at: delivery + 5.days
      )
      [ 12, 16, 20 ].each do |weeks|
        next if dum + weeks.weeks < first_consult

        persist_clinical_record!(
          citizen: citizen,
          record_type: "FVD",
          payload_json: { "motivosVisita" => [ { "codigo" => 1 } ] },
          encounter_at: dum + weeks.weeks
        )
      end
    end

    result = evaluate_c3!(citizen: citizen, rule_code: "E", reference_date: reference_date)

    expect(result.meets_numerator).to be(true)
  end

  it "scores C2-E when FV vaccination record exists" do
    sync_pni_calendar!(export_json: false, publish_release: false)

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
      seed_pni_compliant_immunizations!(citizen: citizen)
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

  it "excludes C2-E citizens from denominator when PNI calendar is not loaded" do
    sync_pni_calendar!(export_json: false, publish_release: false)
    PniScheduleEntry.update_all(active: false)

    citizen = with_tenant(membership) do
      create(
        :citizen,
        municipality: municipality,
        health_facility: facility,
        care_team: team,
        birth_date: Date.current - 18.months,
        full_name: "Criança Sem Calendário"
      )
    end

    result = with_tenant(membership) do
      described_class.evaluate(
        expression: expression_for("C2", rule_code: "E"),
        context: Indicators::DslV1::Context.new(citizen: citizen, reference_date: Date.current)
      )
    end

    expect(result.in_denominator).to be(false)
    expect(result.meets_numerator).to be(false)
  end

  it "scores C2-E when clinical_record.encounter_at is nil but linked encounter has date" do
    sync_pni_calendar!(export_json: false, publish_release: false)

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
      seed_pni_compliant_immunizations!(citizen: citizen)
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
    sync_pni_calendar!(export_json: false, publish_release: false)

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

  it "scores C2-E from nested LEDI FV vacinacoes when doses are applied on time" do
    sync_pni_calendar!(export_json: false, publish_release: false)

    citizen = with_tenant(membership) do
      create(
        :citizen,
        municipality: municipality,
        health_facility: facility,
        care_team: team,
        birth_date: Date.current - 18.months,
        full_name: "Criança FV LEDI",
        cpf: "52998224725"
      )
    end

    with_tenant(membership) do
      PniScheduleEntry.effective_on(Date.current).for_age_group("child").find_each do |entry|
        next unless entry.min_age_days <= ((Date.current - citizen.birth_date).to_i)

        applied_on = citizen.birth_date + [ entry.min_age_days + 1, entry.max_age_days ].min.days
        persist_clinical_record!(
          citizen: citizen,
          record_type: "FV",
          payload_json: {
            "vacinacoes" => [
              {
                "cpfCidadao" => citizen.cpf,
                "dataAtendimento" => applied_on.iso8601,
                "vacinas" => [
                  {
                    "imunobiologico" => entry.immunobiological_code.to_i,
                    "dose" => entry.dose_code
                  }
                ]
              }
            ]
          },
          encounter_at: applied_on
        )
      end
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
          payload_json: {
          "dumDaGestante" => dum_date.iso8601,
          "atendimentos_individuais" => [ { "tipo" => "consulta" } ]
        },
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

  it "does not score V_SAT until external satisfaction import exists" do
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
    expect(result.meets_numerator).to be(false)
  end

  it "validates microarea_linked when FCI and FCD microArea match" do
    citizen = with_tenant(membership) do
      create(
        :citizen,
        municipality: municipality,
        health_facility: facility,
        care_team: team,
        birth_date: Date.new(1980, 1, 1),
        full_name: "Microarea Test"
      )
    end

    with_tenant(membership) do
      persist_fci!(citizen: citizen)
      persist_fcd!(citizen: citizen)
    end

    result = with_tenant(membership) do
      described_class.evaluate(
        expression: {
          "version" => "dsl_v1",
          "denominator" => { "type" => "citizens_on_team" },
          "numerator" => { "type" => "microarea_linked" }
        },
        context: Indicators::DslV1::Context.new(citizen: citizen)
      )
    end

    expect(result.meets_numerator).to be(true)
  end

  it "detects PBF flag in FCI" do
    citizen = with_tenant(membership) do
      create(
        :citizen,
        municipality: municipality,
        health_facility: facility,
        care_team: team,
        birth_date: Date.new(1980, 1, 1),
        full_name: "PBF Test"
      )
    end

    with_tenant(membership) do
      persist_fci!(citizen: citizen, extra_payload: { "stRecebeBeneficioBolsaFamilia" => true })
    end

    result = with_tenant(membership) do
      described_class.evaluate(
        expression: {
          "version" => "dsl_v1",
          "denominator" => { "type" => "citizens_on_team" },
          "numerator" => { "type" => "fci_flag_present", "flag" => "pbf" }
        },
        context: Indicators::DslV1::Context.new(citizen: citizen)
      )
    end

    expect(result.meets_numerator).to be(true)
  end

  it "detects BPC flag in FCI" do
    citizen = with_tenant(membership) do
      create(
        :citizen,
        municipality: municipality,
        health_facility: facility,
        care_team: team,
        birth_date: Date.new(1980, 1, 1),
        full_name: "BPC Test"
      )
    end

    with_tenant(membership) do
      persist_fci!(citizen: citizen, extra_payload: { "stRecebeBPC" => true })
    end

    result = with_tenant(membership) do
      described_class.evaluate(
        expression: {
          "version" => "dsl_v1",
          "denominator" => { "type" => "citizens_on_team" },
          "numerator" => { "type" => "fci_flag_present", "flag" => "bpc" }
        },
        context: Indicators::DslV1::Context.new(citizen: citizen)
      )
    end

    expect(result.meets_numerator).to be(true)
  end

  it "scores C3-F when dTpa is applied from the 20th gestational week" do
    reference_date = Date.new(2026, 5, 30)
    dum = reference_date - 6.months
    vaccination_at = dum + 22.weeks

    citizen = with_tenant(membership) do
      create(
        :citizen,
        municipality: municipality,
        health_facility: facility,
        care_team: team,
        birth_date: Date.new(1995, 3, 15),
        full_name: "Gestante dTpa",
        sex: "female"
      )
    end

    with_tenant(membership) do
      persist_fci_pregnant!(citizen: citizen, encounter_at: reference_date - 2.months)
      persist_clinical_record!(
        citizen: citizen,
        record_type: "FAI",
        payload_json: { "dumDaGestante" => dum.iso8601 },
        encounter_at: dum + 8.weeks
      )
      persist_clinical_record!(
        citizen: citizen,
        record_type: "FV",
        payload_json: { "vacinas" => [ { "imunobiologico" => "dTpa adulto" } ] },
        encounter_at: vaccination_at
      )
    end

    result = with_tenant(membership) do
      described_class.evaluate(
        expression: expression_for("C3", rule_code: "F"),
        context: Indicators::DslV1::Context.new(citizen: citizen, reference_date: reference_date)
      )
    end

    expect(result.in_denominator).to be(true)
    expect(result.meets_numerator).to be(true)
  end

  it "scores C3-F for ended pregnancy when reference_date is after delivery" do
    reference_date = Date.new(2026, 5, 30)
    dum = reference_date - 10.months
    delivery = dum + 280.days
    vaccination_at = dum + 22.weeks

    citizen = with_tenant(membership) do
      create(
        :citizen,
        municipality: municipality,
        health_facility: facility,
        care_team: team,
        birth_date: Date.new(1995, 3, 15),
        full_name: "Gestante dTpa Retroativa",
        sex: "female"
      )
    end

    with_tenant(membership) do
      persist_fci_pregnant!(citizen: citizen, encounter_at: delivery - 1.month)
      persist_clinical_record!(
        citizen: citizen,
        record_type: "FAI",
        payload_json: { "dumDaGestante" => dum.iso8601 },
        encounter_at: dum + 8.weeks
      )
      persist_clinical_record!(
        citizen: citizen,
        record_type: "FV",
        payload_json: { "vacinas" => [ { "imunobiologico" => "dTpa adulto" } ] },
        encounter_at: vaccination_at
      )
      persist_clinical_record!(
        citizen: citizen,
        record_type: "FAI",
        payload_json: { "dataParto" => delivery.iso8601 },
        encounter_at: delivery
      )
    end

    result = with_tenant(membership) do
      described_class.evaluate(
        expression: expression_for("C3", rule_code: "F"),
        context: Indicators::DslV1::Context.new(citizen: citizen, reference_date: reference_date)
      )
    end

    expect(result.meets_numerator).to be(true)
  end

  it "does not score C3-F when dTpa is before the 20th gestational week" do
    reference_date = Date.new(2026, 5, 30)
    dum = reference_date - 6.months
    vaccination_at = dum + 18.weeks

    citizen = with_tenant(membership) do
      create(
        :citizen,
        municipality: municipality,
        health_facility: facility,
        care_team: team,
        birth_date: Date.new(1995, 3, 15),
        full_name: "Gestante dTpa cedo",
        sex: "female"
      )
    end

    with_tenant(membership) do
      persist_fci_pregnant!(citizen: citizen, encounter_at: reference_date - 2.months)
      persist_clinical_record!(
        citizen: citizen,
        record_type: "FAI",
        payload_json: { "dumDaGestante" => dum.iso8601 },
        encounter_at: dum + 8.weeks
      )
      persist_clinical_record!(
        citizen: citizen,
        record_type: "FV",
        payload_json: { "vacinas" => [ { "imunobiologico" => "dTpa adulto", "codigoImunobiologico" => "57" } ] },
        encounter_at: vaccination_at
      )
    end

    result = with_tenant(membership) do
      described_class.evaluate(
        expression: expression_for("C3", rule_code: "F"),
        context: Indicators::DslV1::Context.new(citizen: citizen, reference_date: reference_date)
      )
    end

    expect(result.meets_numerator).to be(false)
  end

  it "does not score C3-G when prenatal tests occur after the first trimester" do
    reference_date = Date.new(2026, 5, 30)
    dum = reference_date - 3.months
    test_at = dum + 20.weeks

    citizen = with_tenant(membership) do
      create(
        :citizen,
        municipality: municipality,
        health_facility: facility,
        care_team: team,
        birth_date: Date.new(1995, 3, 15),
        full_name: "Gestante 2T teste",
        sex: "female"
      )
    end

    with_tenant(membership) do
      persist_fci_pregnant!(citizen: citizen, encounter_at: reference_date - 2.months)
      persist_clinical_record!(
        citizen: citizen,
        record_type: "FAI",
        payload_json: {
          "dumDaGestante" => dum.iso8601,
          "procedimentos" => [ { "co_ms_procedimento" => "0214010040" } ]
        },
        encounter_at: test_at
      )
    end

    result = with_tenant(membership) do
      described_class.evaluate(
        expression: expression_for("C3", rule_code: "G"),
        context: Indicators::DslV1::Context.new(citizen: citizen, reference_date: reference_date)
      )
    end

    expect(result.meets_numerator).to be(false)
  end

  it "scores C3-G when first-trimester prenatal tests are documented" do
    reference_date = Date.new(2026, 5, 30)
    dum = reference_date - 3.months
    test_at = dum + 10.weeks

    citizen = with_tenant(membership) do
      create(
        :citizen,
        municipality: municipality,
        health_facility: facility,
        care_team: team,
        birth_date: Date.new(1995, 3, 15),
        full_name: "Gestante 1T",
        sex: "female"
      )
    end

    with_tenant(membership) do
      persist_fci_pregnant!(citizen: citizen, encounter_at: reference_date - 2.months)
      persist_clinical_record!(
        citizen: citizen,
        record_type: "FAI",
        payload_json: {
          "dumDaGestante" => dum.iso8601,
          "procedimentos" => [ { "co_ms_procedimento" => "0214010040" } ]
        },
        encounter_at: test_at
      )
    end

    result = with_tenant(membership) do
      described_class.evaluate(
        expression: expression_for("C3", rule_code: "G"),
        context: Indicators::DslV1::Context.new(citizen: citizen, reference_date: reference_date)
      )
    end

    expect(result.meets_numerator).to be(true)
  end

  it "scores C3-G for ended pregnancy when reference_date is after delivery" do
    reference_date = Date.new(2026, 5, 30)
    dum = reference_date - 10.months
    delivery = dum + 280.days
    test_at = dum + 10.weeks

    citizen = with_tenant(membership) do
      create(
        :citizen,
        municipality: municipality,
        health_facility: facility,
        care_team: team,
        birth_date: Date.new(1995, 3, 15),
        full_name: "Gestante 1T Retroativa",
        sex: "female"
      )
    end

    with_tenant(membership) do
      persist_fci_pregnant!(citizen: citizen, encounter_at: delivery - 1.month)
      persist_clinical_record!(
        citizen: citizen,
        record_type: "FAI",
        payload_json: {
          "dumDaGestante" => dum.iso8601,
          "procedimentos" => [ { "co_ms_procedimento" => "0214010040" } ]
        },
        encounter_at: test_at
      )
      persist_clinical_record!(
        citizen: citizen,
        record_type: "FAI",
        payload_json: { "dataParto" => delivery.iso8601 },
        encounter_at: delivery
      )
    end

    result = with_tenant(membership) do
      described_class.evaluate(
        expression: expression_for("C3", rule_code: "G"),
        context: Indicators::DslV1::Context.new(citizen: citizen, reference_date: reference_date)
      )
    end

    expect(result.meets_numerator).to be(true)
  end

  it "scores C3-H for ended pregnancy when reference_date is after delivery" do
    reference_date = Date.new(2026, 5, 30)
    dum = reference_date - 10.months
    delivery = dum + 280.days
    test_at = dum + 30.weeks

    citizen = with_tenant(membership) do
      create(
        :citizen,
        municipality: municipality,
        health_facility: facility,
        care_team: team,
        birth_date: Date.new(1995, 3, 15),
        full_name: "Gestante 3T Retroativa",
        sex: "female"
      )
    end

    with_tenant(membership) do
      persist_fci_pregnant!(citizen: citizen, encounter_at: delivery - 1.month)
      persist_clinical_record!(
        citizen: citizen,
        record_type: "FAI",
        payload_json: {
          "dumDaGestante" => dum.iso8601,
          "procedimentos" => [ { "co_ms_procedimento" => "0214010058" } ]
        },
        encounter_at: test_at
      )
      persist_clinical_record!(
        citizen: citizen,
        record_type: "FAI",
        payload_json: { "dataParto" => delivery.iso8601 },
        encounter_at: delivery
      )
    end

    result = with_tenant(membership) do
      described_class.evaluate(
        expression: expression_for("C3", rule_code: "H"),
        context: Indicators::DslV1::Context.new(citizen: citizen, reference_date: reference_date)
      )
    end

    expect(result.meets_numerator).to be(true)
  end

  it "scores C3-H when third-trimester prenatal tests are documented" do
    reference_date = Date.new(2026, 5, 30)
    dum = reference_date - 8.months
    test_at = dum + 30.weeks

    citizen = with_tenant(membership) do
      create(
        :citizen,
        municipality: municipality,
        health_facility: facility,
        care_team: team,
        birth_date: Date.new(1995, 3, 15),
        full_name: "Gestante 3T",
        sex: "female"
      )
    end

    with_tenant(membership) do
      persist_fci_pregnant!(citizen: citizen, encounter_at: reference_date - 2.months)
      persist_clinical_record!(
        citizen: citizen,
        record_type: "FAI",
        payload_json: {
          "dumDaGestante" => dum.iso8601,
          "procedimentos" => [ { "co_ms_procedimento" => "0214010058" } ]
        },
        encounter_at: test_at
      )
    end

    result = with_tenant(membership) do
      described_class.evaluate(
        expression: expression_for("C3", rule_code: "H"),
        context: Indicators::DslV1::Context.new(citizen: citizen, reference_date: reference_date)
      )
    end

    expect(result.meets_numerator).to be(true)
  end

  it "scores C3-I and C3-J in the puerperium window after delivery" do
    reference_date = Date.new(2026, 5, 30)
    delivery = reference_date - 3.weeks
    consult_at = delivery + 10.days

    citizen = with_tenant(membership) do
      create(
        :citizen,
        municipality: municipality,
        health_facility: facility,
        care_team: team,
        birth_date: Date.new(1995, 3, 15),
        full_name: "Puérpera",
        sex: "female"
      )
    end

    with_tenant(membership) do
      persist_fci_pregnant!(citizen: citizen, encounter_at: reference_date - 4.months)
      persist_clinical_record!(
        citizen: citizen,
        record_type: "FAI",
        payload_json: { "dataParto" => delivery.iso8601 },
        encounter_at: delivery
      )
      persist_clinical_record!(
        citizen: citizen,
        record_type: "FAI",
        payload_json: { "atendimentos_individuais" => [ { "tipo" => "consulta" } ] },
        encounter_at: consult_at
      )
      persist_clinical_record!(
        citizen: citizen,
        record_type: "FVD",
        payload_json: { "motivosVisita" => [ 1 ] },
        encounter_at: consult_at + 1.day
      )
    end

    consult_result = with_tenant(membership) do
      described_class.evaluate(
        expression: expression_for("C3", rule_code: "I"),
        context: Indicators::DslV1::Context.new(citizen: citizen, reference_date: reference_date)
      )
    end
    visit_result = with_tenant(membership) do
      described_class.evaluate(
        expression: expression_for("C3", rule_code: "J"),
        context: Indicators::DslV1::Context.new(citizen: citizen, reference_date: reference_date)
      )
    end

    expect(consult_result.meets_numerator).to be(true)
    expect(visit_result.meets_numerator).to be(true)
  end

  it "does not score C3-I when only the delivery FAI exists in puerperium" do
    reference_date = Date.new(2026, 5, 30)
    delivery = reference_date - 3.weeks

    citizen = with_tenant(membership) do
      create(
        :citizen,
        municipality: municipality,
        health_facility: facility,
        care_team: team,
        birth_date: Date.new(1995, 3, 15),
        full_name: "Puérpera sem consulta",
        sex: "female"
      )
    end

    with_tenant(membership) do
      persist_fci_pregnant!(citizen: citizen, encounter_at: reference_date - 4.months)
      persist_clinical_record!(
        citizen: citizen,
        record_type: "FAI",
        payload_json: { "dataParto" => delivery.iso8601 },
        encounter_at: delivery
      )
    end

    result = with_tenant(membership) do
      described_class.evaluate(
        expression: expression_for("C3", rule_code: "I"),
        context: Indicators::DslV1::Context.new(citizen: citizen, reference_date: reference_date)
      )
    end

    expect(result.meets_numerator).to be(false)
  end

  it "does not score C3-I when puerperium consult occurs after 42 days" do
    reference_date = Date.new(2026, 5, 30)
    delivery = reference_date - 8.weeks
    consult_at = delivery + 43.days

    citizen = with_tenant(membership) do
      create(
        :citizen,
        municipality: municipality,
        health_facility: facility,
        care_team: team,
        birth_date: Date.new(1995, 3, 15),
        full_name: "Puérpera tardia",
        sex: "female"
      )
    end

    with_tenant(membership) do
      persist_fci_pregnant!(citizen: citizen, encounter_at: reference_date - 5.months)
      persist_clinical_record!(
        citizen: citizen,
        record_type: "FAI",
        payload_json: { "dataParto" => delivery.iso8601 },
        encounter_at: delivery
      )
      persist_clinical_record!(
        citizen: citizen,
        record_type: "FAI",
        payload_json: { "atendimentos_individuais" => [ { "tipo" => "consulta" } ] },
        encounter_at: consult_at
      )
    end

    result = with_tenant(membership) do
      described_class.evaluate(
        expression: expression_for("C3", rule_code: "I"),
        context: Indicators::DslV1::Context.new(citizen: citizen, reference_date: reference_date)
      )
    end

    expect(result.meets_numerator).to be(false)
  end

  it "does not score C3-I when puerperium FAI lacks individual attendances" do
    reference_date = Date.new(2026, 5, 30)
    delivery = reference_date - 3.weeks
    consult_at = delivery + 10.days

    citizen = with_tenant(membership) do
      create(
        :citizen,
        municipality: municipality,
        health_facility: facility,
        care_team: team,
        birth_date: Date.new(1995, 3, 15),
        full_name: "Puérpera sem atendimento",
        sex: "female"
      )
    end

    with_tenant(membership) do
      persist_fci_pregnant!(citizen: citizen, encounter_at: reference_date - 4.months)
      persist_clinical_record!(
        citizen: citizen,
        record_type: "FAI",
        payload_json: { "dataParto" => delivery.iso8601 },
        encounter_at: delivery
      )
      persist_clinical_record!(
        citizen: citizen,
        record_type: "FAI",
        payload_json: {},
        encounter_at: consult_at
      )
    end

    result = with_tenant(membership) do
      described_class.evaluate(
        expression: expression_for("C3", rule_code: "I"),
        context: Indicators::DslV1::Context.new(citizen: citizen, reference_date: reference_date)
      )
    end

    expect(result.meets_numerator).to be(false)
  end

  it "does not score C3-J when puerperium FVD lacks visit reasons" do
    reference_date = Date.new(2026, 5, 30)
    delivery = reference_date - 3.weeks
    visit_at = delivery + 10.days

    citizen = with_tenant(membership) do
      create(
        :citizen,
        municipality: municipality,
        health_facility: facility,
        care_team: team,
        birth_date: Date.new(1995, 3, 15),
        full_name: "Puérpera sem motivo visita",
        sex: "female"
      )
    end

    with_tenant(membership) do
      persist_fci_pregnant!(citizen: citizen, encounter_at: reference_date - 4.months)
      persist_clinical_record!(
        citizen: citizen,
        record_type: "FAI",
        payload_json: { "dataParto" => delivery.iso8601 },
        encounter_at: delivery
      )
      persist_clinical_record!(
        citizen: citizen,
        record_type: "FVD",
        payload_json: {},
        encounter_at: visit_at
      )
    end

    result = with_tenant(membership) do
      described_class.evaluate(
        expression: expression_for("C3", rule_code: "J"),
        context: Indicators::DslV1::Context.new(citizen: citizen, reference_date: reference_date)
      )
    end

    expect(result.meets_numerator).to be(false)
  end

  it "scores C4-E when HbA1c procedure is present" do
    citizen = with_tenant(membership) do
      create(
        :citizen,
        municipality: municipality,
        health_facility: facility,
        care_team: team,
        birth_date: Date.new(1970, 1, 1),
        full_name: "Diabético HbA1c"
      )
    end

    with_tenant(membership) do
      persist_fci_diabetic!(citizen: citizen, encounter_at: 1.month.ago)
      persist_clinical_record!(
        citizen: citizen,
        record_type: "FAI",
        payload_json: { "procedimentos" => [ { "co_ms_procedimento" => "0202010503" } ] },
        encounter_at: 2.months.ago
      )
    end

    result = with_tenant(membership) do
      described_class.evaluate(
        expression: expression_for("C4", rule_code: "E"),
        context: Indicators::DslV1::Context.new(citizen: citizen, reference_date: Date.current)
      )
    end

    expect(result.meets_numerator).to be(true)
  end

  it "scores C6-D when influenza vaccination is documented for elderly citizens" do
    citizen = with_tenant(membership) do
      create(
        :citizen,
        municipality: municipality,
        health_facility: facility,
        care_team: team,
        birth_date: Date.new(1950, 1, 1),
        full_name: "Idoso Influenza"
      )
    end

    with_tenant(membership) do
      persist_fci!(citizen: citizen, extra_payload: { "idoso" => true })
      persist_clinical_record!(
        citizen: citizen,
        record_type: "FV",
        payload_json: { "vacinas" => [ { "imunobiologico" => "Influenza trivalente" } ] },
        encounter_at: 3.months.ago
      )
    end

    result = with_tenant(membership) do
      described_class.evaluate(
        expression: expression_for("C6", rule_code: "D"),
        context: Indicators::DslV1::Context.new(citizen: citizen, reference_date: Date.current)
      )
    end

    expect(result.in_denominator).to be(true)
    expect(result.meets_numerator).to be(true)
  end

  it "does not match dTpa via substring inside unrelated vaccine names" do
    payload = { "vacinas" => [ { "imunobiologico" => "Vacina antidTpa placeholder" } ] }

    expect(
      Indicators::DslV1::Resolvers::ClinicalEvidence.send(:vaccination_match?, payload, "dTpa")
    ).to be(false)
  end

  it "matches dTpa by immunobiological code 57" do
    payload = { "vacinas" => [ { "codigoImunobiologico" => "57", "imunobiologico" => "Outro rótulo" } ] }

    expect(
      Indicators::DslV1::Resolvers::ClinicalEvidence.send(
        :vaccination_match?,
        payload,
        "dTpa",
        immunobiological_code: "57"
      )
    ).to be(true)
  end

  it "rejects MICI completion when FCI identificacao is missing required fields" do
    citizen = with_tenant(membership) do
      create(
        :citizen,
        municipality: municipality,
        health_facility: facility,
        care_team: team,
        birth_date: Date.new(1980, 1, 1),
        full_name: "Fallback Test"
      )
    end

    with_tenant(membership) do
      persist_clinical_record!(
        citizen: citizen,
        record_type: "FCI",
        payload_json: { "identificacaoUsuarioCidadao" => { "nome" => citizen.full_name } },
        encounter_at: 1.month.ago
      )
      persist_fcd!(citizen: citizen)
    end

    result = with_tenant(membership) do
      described_class.evaluate(
        expression: expression_for("V_CAD"),
        context: Indicators::DslV1::Context.new(citizen: citizen)
      )
    end

    expect(result.meets_numerator).to be(false)
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
    quadrimester = Indicators::Quadrimester.current
    encounter_at = 1.month.ago

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
          encounter_at: encounter_at
        )
      end
    end

    score = with_tenant(membership) do
      described_class.team_score(
        expression: expression_for("B3"),
        citizens: Citizen.where(id: citizens.map(&:id)),
        quadrimester: quadrimester,
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

  it "scores C3-K when dental first consult occurs in gestational window" do
    reference_date = Date.new(2026, 5, 30)
    dum = reference_date - 4.months
    consult_at = dum + 12.weeks

    citizen = with_tenant(membership) do
      create(
        :citizen,
        municipality: municipality,
        health_facility: facility,
        care_team: team,
        birth_date: Date.new(1995, 3, 15),
        full_name: "Gestante Odonto",
        sex: "female"
      )
    end

    with_tenant(membership) do
      persist_fci_pregnant!(citizen: citizen, encounter_at: reference_date - 2.months)
      persist_clinical_record!(
        citizen: citizen,
        record_type: "FAI",
        payload_json: { "dumDaGestante" => dum.iso8601 },
        encounter_at: dum + 1.week
      )
      persist_clinical_record!(
        citizen: citizen,
        record_type: "FAO",
        payload_json: {
          "atendimentos_odontologicos" => [
            { "tipos_consulta_odonto" => [ 1 ], "cpfCidadao" => citizen.cpf }
          ]
        },
        encounter_at: consult_at
      )
    end

    result = with_tenant(membership) do
      described_class.evaluate(
        expression: expression_for("C3", rule_code: "K"),
        context: Indicators::DslV1::Context.new(citizen: citizen, reference_date: reference_date)
      )
    end

    expect(result.meets_numerator).to be(true)
  end

  it "limits C7-B denominator to women aged 50-69" do
    young = with_tenant(membership) do
      create(
        :citizen,
        municipality: municipality,
        health_facility: facility,
        care_team: team,
        birth_date: Date.current - 40.years,
        sex: "female"
      )
    end

    result = with_tenant(membership) do
      described_class.evaluate(
        expression: expression_for("C7", rule_code: "B"),
        context: Indicators::DslV1::Context.new(citizen: young, reference_date: Date.current)
      )
    end

    expect(result.in_denominator).to be(false)
  end

  it "scores V_SAT from imported team satisfaction survey" do
    with_tenant(membership) do
      TeamSatisfactionSurveyScore.create!(
        municipality: municipality,
        care_team: team,
        reference_month: Date.current.beginning_of_month,
        score: 8.0
      )
    end

    citizen = with_tenant(membership) do
      create(:citizen, municipality: municipality, health_facility: facility, care_team: team)
    end

    result = with_tenant(membership) do
      described_class.evaluate(
        expression: expression_for("V_SAT"),
        context: Indicators::DslV1::Context.new(
          citizen: citizen,
          care_team: team,
          reference_date: Date.current
        )
      )
    end

    expect(result.meets_numerator).to be(true)
  end
end
