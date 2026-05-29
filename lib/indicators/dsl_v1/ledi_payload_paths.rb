# frozen_string_literal: true

module Indicators
  module DslV1
    # LEDI/e-SUS payload field names (external schema). Values stay in Portuguese because
    # they mirror upstream JSON keys; internal code must reference them only via this module.
    module LediPayloadPaths
      PAYLOAD_FIELD_KEYS = {
        "individual_attendances" => "atendimentos_individuais",
        "measurements" => "medicoes",
        "immunizations" => "vacina",
        "child_development" => "desenvolvimento_infantil"
      }.freeze

      PAYLOAD_FIELD_ALIASES = {
        "immunizations" => %w[vacina vacinas vacinacoes imunizacoes],
        "child_development" => %w[desenvolvimento_infantil marcadores_desenvolvimento avaliacao_desenvolvimento]
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
        "female_screening" => %w[mulher rastreamento_cancer mulher_rastreamento]
      }.freeze

      FEMALE_SEX_VALUES = %w[2 F female feminino].freeze

      NESTED_ATTENDANCE_KEYS = {
        "FAO" => %w[atendimentos_odontologicos atendimentosOdontologicos],
        "FAC" => %w[atividade_coletiva atividadeColetiva],
        "FAI" => %w[atendimentos_individuais atendimentosIndividuais],
        "FCC" => %w[cuidados_compartilhados cuidadosCompartilhados]
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
