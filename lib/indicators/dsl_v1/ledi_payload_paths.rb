# frozen_string_literal: true

module Indicators
  module DslV1
    # LEDI/e-SUS payload field names (external schema). Values stay in Portuguese because
    # they mirror upstream JSON keys; internal code must reference them only via this module.
    module LediPayloadPaths
      PAYLOAD_FIELD_KEYS = {
        "individual_attendances" => "atendimentos_individuais",
        "visit_reasons" => "motivosVisita",
        "measurements" => "medicoes",
        "immunizations" => "vacina",
        "child_development" => "desenvolvimento_infantil"
      }.freeze

      PAYLOAD_FIELD_ALIASES = {
        "immunizations" => %w[vacina vacinas vacinacoes imunizacoes],
        "child_development" => %w[desenvolvimento_infantil marcadores_desenvolvimento avaliacao_desenvolvimento],
        "visit_reasons" => %w[motivosVisita motivos_visita]
      }.freeze

      PRENATAL_INDIVIDUAL_ATTENDANCE_PREDICATE = {
        "type" => "present",
        "field_path" => "individual_attendances"
      }.freeze

      PRENATAL_VISIT_REASONS_PREDICATE = {
        "type" => "present",
        "field_path" => "visit_reasons"
      }.freeze

      FCI_HEALTH_CONDITION_SECTIONS = %w[
        condicoes_de_saude
        situacao_de_saude
        condicoesDeSaude
        situacaoDeSaude
      ].freeze

      FCI_CONDITION_FIELD_ALIASES = {
        "diabetes" => %w[diabetes st_diabetes possui_diabetes],
        "hypertension" => %w[hipertensao hipertensao_arterial st_hipertensao_arterial],
        "pregnant" => %w[gestante st_gestante esta_gestante],
        "elderly" => %w[idoso st_idoso],
        "female_screening" => %w[mulher rastreamento_cancer mulher_rastreamento],
        "pbf" => %w[stRecebeBeneficioBolsaFamilia recebeBeneficioBolsaFamilia st_bolsa_familia recebeBolsaFamilia],
        "bpc" => %w[stRecebeBPC recebeBPC st_bpc recebe_bpc]
      }.freeze

      # Nota C3 Quadro 07 — 1º trimestre: sífilis, HIV e hepatites B/C.
      # G and H share SIGTAP codes; gestational week window (0–13 vs 28–42) disambiguates trimester.
      PRENATAL_FIRST_TRIMESTER_PROCEDURE_CODES = %w[
        0214010040 0214010279 0214010058 0214010074 0214010082 0214010252
        0214010090 0214010104 0214010236 0214010309
        0213010780 0213010500
        0202031098 0202031110 0202031179
      ].freeze

      # 3º trimestre: sífilis e HIV apenas (mesmos códigos SIGTAP, sem hepatites).
      PRENATAL_THIRD_TRIMESTER_PROCEDURE_CODES = %w[
        0214010040 0214010279 0214010058 0214010074 0214010082 0214010252
        0213010780 0213010500
        0202031098 0202031110 0202031179
      ].freeze

      DTPA_VACCINE_CODES = %w[57 057].freeze

      FEMALE_SEX_VALUES = %w[2 F female feminino].freeze

      NESTED_ATTENDANCE_KEYS = {
        "FAO" => %w[atendimentos_odontologicos atendimentosOdontologicos],
        "FAC" => %w[atividade_coletiva atividadeColetiva],
        "FAI" => %w[atendimentos_individuais atendimentosIndividuais],
        "FCC" => %w[cuidados_compartilhados cuidadosCompartilhados],
        "FVD" => %w[visitasDomiciliares visitas_domiciliares]
      }.freeze

      DENTAL_FIRST_CONSULT_TYPE_CODES = [ 1, "1" ].freeze
      DENTAL_TREATMENT_COMPLETE_ENC_CODES = [ 15, 16, "15", "16" ].freeze
      SUPERVISED_BRUSHING_PRACTICE_CODE = 9
      TRA_PROCEDURE_CODE_PREFIXES = %w[030701 030702 030703].freeze
      PREVENTIVE_PROCEDURE_CODE_PREFIXES = %w[010102 010104 010105 030101 030106].freeze
      EXTRACTION_PROCEDURE_CODE_PREFIXES = %w[041402 041403 041404].freeze
      EMULTI_CBO_PREFIXES = %w[2235 2236 2237 2238 2239 2241 2515 2516 3222 5151].freeze

      module_function

      def payload_field(key)
        PAYLOAD_FIELD_KEYS.fetch(key.to_s, key.to_s)
      end

      def payload_field_aliases(key)
        PAYLOAD_FIELD_ALIASES.fetch(key.to_s, [ payload_field(key) ])
      end

      def fci_condition_field_aliases(flag)
        FCI_CONDITION_FIELD_ALIASES.fetch(flag.to_s, [ flag.to_s ])
      end
    end
  end
end
