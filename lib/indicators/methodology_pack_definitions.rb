# frozen_string_literal: true

module Indicators
  # Source of truth for methodology packs (Portaria 3.493 / SAPS Notas Metodológicas).
  # MethodologyPackLoader exports each entry to lib/indicators/methodology/3493-2024/packs/*.json
  module MethodologyPackDefinitions
    ESF_AP_SOURCE = "https://www.gov.br/saude/pt-br/composicao/saps/publicacoes/fichas-tecnicas/equipe-de-atencao-primaria-e-saude-da-familia"
    ESB_SOURCE = "https://www.gov.br/saude/pt-br/composicao/saps/publicacoes/fichas-tecnicas/equipe-de-saude-bucal"
    EMULTI_SOURCE = "https://www.gov.br/saude/pt-br/composicao/saps/publicacoes/fichas-tecnicas/equipes-multiprofissionais-emulti"

    ON_TEAM = { "type" => "citizens_on_team" }.freeze

    module_function

    def all
      linkage_packs + quality_packs + dental_packs + emulti_packs
    end

    def linkage_packs
      [
        pack(
          code: "CVAT", rule_code: "default", good_practice_code: nil,
          funding_component: "linkage", team_kind: "esf", display_order: 0,
          source_ref: ESF_AP_SOURCE,
          expression: {
            "denominator" => ON_TEAM,
            "numerator" => ON_TEAM,
            "skip_citizen_gaps" => true,
            "score_scale" => "ms_0_10",
            "team_score_mode" => "linkage_aggregate",
            "linkage_monthly_average" => true,
            "linkage_components" => [
              { "code" => "V_CAD", "weight" => 3.0 },
              { "code" => "V_ACOMP", "weight" => 7.0 }
            ],
            "linkage_sat_bonus" => { "code" => "V_SAT", "max_bonus" => 1.0, "external_until_import" => true }
          }
        ),
        pack(
          code: "V_CAD", rule_code: "default", good_practice_code: "V_CAD_COM",
          funding_component: "linkage", team_kind: "esf", display_order: 1,
          source_ref: ESF_AP_SOURCE,
          numerator_summary: "MICI + MICDT válidos (FCI + FCD)",
          expression: {
            "denominator" => ON_TEAM,
            "numerator" => { "type" => "mici_micdt_complete" }
          }
        ),
        pack(
          code: "V_CAD", rule_code: "cad_atu", good_practice_code: "V_CAD_ATU",
          funding_component: "linkage", team_kind: "esf", display_order: 1,
          source_ref: ESF_AP_SOURCE,
          numerator_summary: "MICI revisado nos últimos 24 meses",
          expression: {
            "denominator" => ON_TEAM,
            "numerator" => { "type" => "fci_updated_within", "within_months" => 24 },
            "skip_team_score" => true
          }
        ),
        pack(
          code: "V_CAD", rule_code: "lim_cad", good_practice_code: "V_LIM_CAD",
          funding_component: "linkage", team_kind: "esf", display_order: 1,
          source_ref: ESF_AP_SOURCE,
          numerator_summary: "Cadastros da equipe dentro do teto Portaria 3.493",
          expression: {
            "denominator" => ON_TEAM,
            "numerator" => { "type" => "registration_within_team_limit", "team_limit" => 3_500 },
            "skip_team_score" => true,
            "caps_linkage_tier" => "good"
          }
        ),
        pack(
          code: "V_ACOMP", rule_code: "default", good_practice_code: "V_ACOMP_12M",
          funding_component: "linkage", team_kind: "esf", display_order: 2,
          source_ref: ESF_AP_SOURCE,
          numerator_summary: "Mais de 1 contato e ao menos 1 atendimento em 12 meses",
          expression: {
            "denominator" => ON_TEAM,
            "numerator" => {
              "type" => "contact_and_attendance",
              "within_months" => 12,
              "minimum_contacts" => 2,
              "minimum_attendances" => 1,
              "record_types" => %w[FAI FAO FP FVD FAC FV MCA]
            }
          }
        ),
        pack(
          code: "V_SAT", rule_code: "default", good_practice_code: "V_SAT",
          funding_component: "linkage", team_kind: "esf", display_order: 3,
          source_ref: ESF_AP_SOURCE,
          numerator_summary: "Satisfação do usuário (import pesquisa MS)",
          expression: {
            "denominator" => ON_TEAM,
            "numerator" => { "type" => "satisfaction_survey", "within_months" => 6, "fallback_encounter" => false, "min_score" => 7.0 }
          }
        )
      ]
    end

    def quality_packs
      c1 + c2 + c3 + c4 + c5 + c6 + c7
    end

    def c1
      [
        pack(
          code: "C1", rule_code: "default", good_practice_code: "A",
          funding_component: "quality", team_kind: "esf", display_order: 10,
          source_ref: ESF_AP_SOURCE,
          numerator_summary: "Proporção de atendimentos programados no quadrimestre",
          expression: {
            "denominator" => ON_TEAM,
            "numerator" => ON_TEAM,
            "team_score_mode" => "programmed_attendance_ratio",
            "skip_citizen_gaps" => true
          }
        )
      ]
    end

    def c2
      base_denom = { "type" => "citizens_age_lte", "max_age" => 2 }
      [
        bp("C2", "A", 11, "1ª consulta até 30º dia", base_denom,
           { "type" => "first_consult_by_age", "record_types" => %w[FAI], "max_days" => 30 }),
        bp("C2", "B", 11, "≥9 consultas até 2 anos", base_denom,
           { "type" => "consult_count_gte", "record_types" => %w[FAI], "within_months" => 24, "minimum_count" => 9 }),
        bp("C2", "C", 11, "≥9 registros peso+altura", base_denom,
           { "type" => "anthropometry_count_gte", "record_types" => %w[FAI FVD FAC], "within_months" => 24, "minimum_count" => 9 }),
        bp("C2", "D", 11, "2 visitas ACS", base_denom,
           {
             "type" => "acs_two_visit_schedule",
             "record_types" => %w[FVD],
             "first_visit_max_days" => 30,
             "second_visit_within_months" => 6
           }),
        bp("C2", "E", 11, "Vacinação calendário infantil", base_denom,
           { "type" => "vaccination_calendar", "record_types" => %w[FV], "within_months" => 24 })
      ]
    end

    def c3
      denom = { "type" => "citizens_with_condition", "source" => "fci", "flag" => "pregnant" }
      letters = {
        "A" => {
          "type" => "first_prenatal_consult",
          "record_types" => %w[FAI],
          "max_weeks" => 12,
          "lookback_months" => 15,
          "predicate" => DslV1::LediPayloadPaths::PRENATAL_INDIVIDUAL_ATTENDANCE_PREDICATE
        },
        "B" => {
          "type" => "gestational_evidence_count_gte",
          "measure" => "consult",
          "record_types" => %w[FAI],
          "minimum_count" => 7,
          "min_gestational_weeks" => 0,
          "max_gestational_weeks" => 42,
          "lookback_months" => 15,
          "active_only" => false,
          "predicate" => DslV1::LediPayloadPaths::PRENATAL_INDIVIDUAL_ATTENDANCE_PREDICATE
        },
        "C" => {
          "type" => "gestational_evidence_count_gte",
          "measure" => "blood_pressure",
          "record_types" => %w[FAI FP FVD],
          "minimum_count" => 7,
          "min_gestational_weeks" => 0,
          "max_gestational_weeks" => 42,
          "lookback_months" => 15,
          "active_only" => false
        },
        "D" => {
          "type" => "gestational_evidence_count_gte",
          "measure" => "anthropometry",
          "record_types" => %w[FAI FVD FP],
          "minimum_count" => 7,
          "min_gestational_weeks" => 0,
          "max_gestational_weeks" => 42,
          "lookback_months" => 15,
          "active_only" => false
        },
        "E" => {
          "type" => "gestational_evidence_count_gte",
          "measure" => "visit",
          "record_types" => %w[FVD],
          "minimum_count" => 3,
          "min_gestational_weeks" => 0,
          "max_gestational_weeks" => 42,
          "lookback_months" => 15,
          "active_only" => false,
          "after_first_prenatal" => true,
          "first_prenatal_predicate" => DslV1::LediPayloadPaths::PRENATAL_INDIVIDUAL_ATTENDANCE_PREDICATE,
          "predicate" => DslV1::LediPayloadPaths::PRENATAL_VISIT_REASONS_PREDICATE
        },
        "F" => {
          "type" => "gestational_vaccination_immunobiologic",
          "record_types" => %w[FV],
          "immunobiologic" => "dTpa",
          "immunobiologic_code" => "57",
          "min_gestational_weeks" => 20,
          "max_gestational_weeks" => 42,
          "lookback_months" => 15,
          "active_only" => false
        },
        "G" => {
          "type" => "gestational_clinical_predicate",
          "record_types" => %w[FAI],
          "min_gestational_weeks" => 0,
          "max_gestational_weeks" => 13,
          "lookback_months" => 15,
          "active_only" => false,
          "predicate" => {
            "type" => "procedure_any_present",
            "codes" => DslV1::LediPayloadPaths::PRENATAL_FIRST_TRIMESTER_PROCEDURE_CODES
          }
        },
        "H" => {
          "type" => "gestational_clinical_predicate",
          "record_types" => %w[FAI],
          "min_gestational_weeks" => 28,
          "max_gestational_weeks" => 42,
          "lookback_months" => 15,
          "active_only" => false,
          "predicate" => {
            "type" => "procedure_any_present",
            "codes" => DslV1::LediPayloadPaths::PRENATAL_THIRD_TRIMESTER_PROCEDURE_CODES
          }
        },
        "I" => {
          "type" => "puerperium_consult",
          "record_types" => %w[FAI],
          "days_after_delivery" => 42,
          "predicate" => DslV1::LediPayloadPaths::PRENATAL_INDIVIDUAL_ATTENDANCE_PREDICATE
        },
        "J" => {
          "type" => "puerperium_visit",
          "record_types" => %w[FVD],
          "days_after_delivery" => 42,
          "minimum_count" => 1,
          "predicate" => DslV1::LediPayloadPaths::PRENATAL_VISIT_REASONS_PREDICATE
        },
        "K" => {
          "type" => "gestational_clinical_predicate",
          "record_types" => %w[FAO],
          "min_gestational_weeks" => 0,
          "max_gestational_weeks" => 42,
          "lookback_months" => 15,
          "active_only" => false,
          "predicate" => { "type" => "dental_first_consult" }
        }
      }
      letters.map do |letter, numerator|
        bp("C3", letter, 12, "Gestante BP #{letter}", denom, numerator)
      end
    end

    def c4
      denom = { "type" => "citizens_with_condition", "source" => "fci", "flag" => "diabetes" }
      [
        bp("C4", "A", 13, "≥1 consulta 6m", denom,
           { "type" => "consult_count_gte", "record_types" => %w[FAI], "within_months" => 6, "minimum_count" => 1 }),
        bp("C4", "B", 13, "≥1 aferição PA 6m", denom,
           { "type" => "blood_pressure_count_gte", "record_types" => %w[FAI FP FVD], "within_months" => 6, "minimum_count" => 1 }),
        bp("C4", "C", 13, "≥2 visitas domiciliares 12m", denom,
           { "type" => "visit_count_gte", "record_types" => %w[FVD], "within_months" => 12, "minimum_count" => 2, "minimum_interval_days" => 30 }),
        bp("C4", "D", 13, "≥1 peso+altura 12m", denom,
           { "type" => "anthropometry_count_gte", "record_types" => %w[FAI FP FVD], "within_months" => 12, "minimum_count" => 1 }),
        bp("C4", "E", 13, "≥1 HbA1c 12m", denom,
           { "type" => "clinical_predicate", "record_types" => %w[FAI], "within_months" => 12,
             "predicate" => { "type" => "procedure_present", "code" => "0202010503" } }),
        bp("C4", "F", 13, "≥1 avaliação dos pés 12m", denom,
           { "type" => "clinical_predicate", "record_types" => %w[FAI FP], "within_months" => 12,
             "predicate" => { "type" => "procedure_present", "code" => "0301040095" } })
      ]
    end

    def c5
      denom = { "type" => "citizens_with_condition", "source" => "fci", "flag" => "hypertension" }
      [
        bp("C5", "A", 14, "≥1 consulta 6m", denom,
           { "type" => "consult_count_gte", "record_types" => %w[FAI], "within_months" => 6, "minimum_count" => 1 }),
        bp("C5", "B", 14, "≥1 aferição PA 6m", denom,
           { "type" => "blood_pressure_count_gte", "record_types" => %w[FAI FP FVD], "within_months" => 6, "minimum_count" => 1 }),
        bp("C5", "C", 14, "≥2 visitas domiciliares 12m", denom,
           { "type" => "visit_count_gte", "record_types" => %w[FVD], "within_months" => 12, "minimum_count" => 2, "minimum_interval_days" => 30 }),
        bp("C5", "D", 14, "≥1 peso+altura 12m", denom,
           { "type" => "anthropometry_count_gte", "record_types" => %w[FAI FP FVD], "within_months" => 12, "minimum_count" => 1 })
      ]
    end

    def c6
      denom = { "type" => "citizens_age_gte", "min_age" => 60 }
      [
        bp("C6", "A", 15, "≥1 consulta 12m", denom,
           { "type" => "consult_count_gte", "record_types" => %w[FAI FAD], "within_months" => 12, "minimum_count" => 1 }),
        bp("C6", "B", 15, "≥2 peso+altura 12m", denom,
           { "type" => "anthropometry_count_gte", "record_types" => %w[FAI FP FVD], "within_months" => 12, "minimum_count" => 2 }),
        bp("C6", "C", 15, "≥2 visitas domiciliares 12m", denom,
           { "type" => "visit_count_gte", "record_types" => %w[FVD], "within_months" => 12, "minimum_count" => 2, "minimum_interval_days" => 30 }),
        bp("C6", "D", 15, "≥1 dose influenza 12m", denom,
           { "type" => "vaccination_immunobiologic", "record_types" => %w[FV], "within_months" => 12, "immunobiologic" => "influenza" })
      ]
    end

    def c7
      [
        bp("C7", "A", 16, "Rastreamento colo do útero", { "type" => "citizens_sex_female" },
           { "type" => "clinical_predicate", "record_types" => %w[FAI FP], "within_months" => 36,
             "predicate" => { "type" => "procedure_present", "code" => "0201020074" } }),
        bp("C7", "B", 16, "Rastreamento mama",
           { "type" => "all", "clauses" => [
             { "type" => "citizens_sex_female" },
             { "type" => "citizens_age_between", "min_age" => 50, "max_age" => 69 }
           ] },
           { "type" => "clinical_predicate", "record_types" => %w[FAI FP], "within_months" => 24,
             "predicate" => { "type" => "procedure_present", "code" => "0204030188" } }),
        bp("C7", "C", 16, "Vacinação HPV",
           { "type" => "all", "clauses" => [
             { "type" => "citizens_sex_female" },
             { "type" => "citizens_age_between", "min_age" => 9, "max_age" => 14 }
           ] },
           { "type" => "vaccination_immunobiologic", "record_types" => %w[FV], "within_months" => 120, "immunobiologic" => "HPV" })
      ]
    end

    def dental_packs
      %w[B1 B2 B4 B5 B6].map do |code|
        pack_for_dental(code)
      end + [ b3_pack ]
    end

    def pack_for_dental(code)
      predicates = {
        "B1" => { "type" => "dental_first_consult" },
        "B2" => { "type" => "dental_treatment_completed" },
        "B4" => { "type" => "supervised_brushing" },
        "B5" => { "type" => "preventive_procedure" },
        "B6" => { "type" => "tra_procedure" }
      }
      records = code == "B4" ? %w[FAC FAO] : %w[FAO]
      pack(
        code: code, rule_code: "default", good_practice_code: code,
        funding_component: "quality", team_kind: "esb",
        display_order: 17 + %w[B1 B2 B3 B4 B5 B6].index(code),
        source_ref: ESB_SOURCE,
        expression: {
          "denominator" => ON_TEAM,
          "numerator" => {
            "type" => "clinical_predicate",
            "record_types" => records,
            "within_months" => 12,
            "predicate" => predicates.fetch(code)
          }
        }
      )
    end

    def b3_pack
      pack(
        code: "B3", rule_code: "default", good_practice_code: "B3",
        funding_component: "quality", team_kind: "esb", display_order: 19,
        source_ref: ESB_SOURCE,
        expression: {
          "denominator" => ON_TEAM,
          "numerator" => { "type" => "encounter_in_window", "within_months" => 3 },
          "team_score_mode" => "procedure_ratio",
          "skip_citizen_gaps" => true
        }
      )
    end

    def emulti_packs
      [
        pack(
          code: "M1", rule_code: "default", good_practice_code: "M1",
          funding_component: "quality", team_kind: "emulti", display_order: 23,
          source_ref: EMULTI_SOURCE,
          expression: {
            "denominator" => ON_TEAM,
            "numerator" => {
              "type" => "emulti_encounter_count",
              "record_types" => %w[FAC FAI FAO],
              "within_months" => 3,
              "minimum_count" => 1
            }
          }
        ),
        pack(
          code: "M2", rule_code: "default", good_practice_code: "M2",
          funding_component: "quality", team_kind: "emulti", display_order: 24,
          source_ref: EMULTI_SOURCE,
          expression: {
            "denominator" => ON_TEAM,
            "numerator" => {
              "type" => "clinical_predicate",
              "record_types" => %w[FAC FCC],
              "within_months" => 12,
              "predicate" => { "type" => "interprofessional_action" }
            }
          }
        )
      ]
    end

    def bp(code, letter, display_order, summary, denominator, numerator)
      pack(
        code: code, rule_code: letter, good_practice_code: letter,
        funding_component: "quality", team_kind: "esf", display_order: display_order,
        source_ref: ESF_AP_SOURCE,
        numerator_summary: summary,
        expression: {
          "denominator" => denominator,
          "numerator" => numerator
        }
      )
    end

    def pack(code:, rule_code:, expression:, funding_component:, team_kind:, display_order:,
             good_practice_code: nil, source_ref: nil, numerator_summary: nil, denominator_summary: nil,
             record_types: nil)
      {
        "catalog" => {
          "code" => code,
          "funding_component" => funding_component,
          "team_kind" => team_kind,
          "display_order" => display_order,
          "methodology_version" => "3493/2024",
          "periodicity" => "quarterly"
        },
        "rule_code" => rule_code,
        "good_practice_code" => good_practice_code,
        "source_ref" => source_ref,
        "numerator_summary" => numerator_summary,
        "denominator_summary" => denominator_summary,
        "record_types" => record_types,
        "expression" => expression
      }
    end
  end
end
