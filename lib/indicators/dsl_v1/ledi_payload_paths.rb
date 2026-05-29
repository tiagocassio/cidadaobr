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
