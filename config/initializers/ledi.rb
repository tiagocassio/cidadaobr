# frozen_string_literal: true

ledi_gen_rb = Rails.root.join("vendor/ledi/7.4.0/gen-rb")
$LOAD_PATH.unshift(ledi_gen_rb.to_s) unless $LOAD_PATH.include?(ledi_gen_rb.to_s)

require "dado_transporte_constants"
require "cadastro_individual_constants"
require "cadastro_domiciliar_constants"
require "common_constants"
require "ficha_atendimento_individual_constants"
require "ficha_atendimento_odonto_constants"
require "ficha_atividade_coletiva_constants"
require "ficha_atendimento_procedimento_constants"
require "ficha_visita_domiciliar_constants"
require "ficha_vacinacao_constants"
require "ficha_atendimento_domiciliar_constants"
require "ficha_avaliacao_elegibilidade_constants"
require "ficha_consumo_alimentar_constants"
require "ficha_complementar_zika_microcefalia_constants"
require "cuidado_compartilhado_constants"

Rails.application.config.ledi = Rails.application.config_for(:ledi)

Rails.application.config.after_initialize do
  Cidadaobr::VendorFingerprint.verify_ledi!(Rails.application.config.ledi)
end
