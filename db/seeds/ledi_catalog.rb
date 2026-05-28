# frozen_string_literal: true

ledi_version = Rails.application.config.ledi.fetch(:version)
tp_cds_origem = Rails.application.config.ledi.fetch(:tp_cds_origem)

def upsert_field!(record_type:, field_path:, data_type:, required: false, ledi_version:, min_occurs: 0, max_occurs: nil)
  LediFieldCatalog.find_or_initialize_by(record_type: record_type, field_path: field_path, ledi_version: ledi_version).tap do |entry|
    entry.assign_attributes(data_type: data_type, required: required, min_occurs: min_occurs, max_occurs: max_occurs)
    entry.save!
  end
end

def upsert_rule!(record_type:, rule_code:, expression:, ledi_version:, severity: "error")
  LediValidationRule.find_or_initialize_by(record_type: record_type, rule_code: rule_code, ledi_version: ledi_version).tap do |rule|
    rule.assign_attributes(expression: expression, severity: severity)
    rule.save!
  end
end

%w[FCI FCD FAI FP FV].each do |record_type|
  upsert_rule!(
    record_type: record_type,
    rule_code: "tp_cds_origem_third_party",
    ledi_version: ledi_version,
    expression: {
      "type" => "equals",
      "field_path" => "tp_cds_origem",
      "value" => tp_cds_origem.to_s,
      "message" => "tpCdsOrigem deve ser #{tp_cds_origem} (software de terceiros)"
    }
  )
end

upsert_rule!(
  record_type: "FCI",
  rule_code: "citizen_identifier_xor",
  ledi_version: ledi_version,
  expression: {
    "type" => "xor_present",
    "fields" => %w[identificacao_usuario_cidadao.cpf_cidadao identificacao_usuario_cidadao.cns_cidadao],
    "message" => "Informe CPF ou CNS do cidadão, mas não ambos"
  }
)

upsert_rule!(
  record_type: "FCI",
  rule_code: "uuid_required",
  ledi_version: ledi_version,
  expression: {
    "type" => "present",
    "field_path" => "uuid",
    "message" => "UUID da ficha é obrigatório"
  }
)

upsert_rule!(
  record_type: "FCI",
  rule_code: "refusal_omits_blocks",
  ledi_version: ledi_version,
  expression: {
    "type" => "absent_when",
    "when_field" => "status_termo_recusa_cadastro_individual_atencao_basica",
    "absent_fields" => %w[condicoes_de_saude identificacao_usuario_cidadao],
    "message" => "Ficha recusada não deve conter blocos de identificação ou condições"
  }
)

upsert_rule!(
  record_type: "FCD",
  rule_code: "uuid_required",
  ledi_version: ledi_version,
  expression: {
    "type" => "present",
    "field_path" => "uuid",
    "message" => "UUID da ficha domiciliar é obrigatório"
  }
)

upsert_rule!(
  record_type: "FCD",
  rule_code: "refusal_omits_address",
  ledi_version: ledi_version,
  expression: {
    "type" => "absent_when",
    "when_field" => "status_termo_recusa",
    "absent_fields" => %w[endereco_local_permanencia familias],
    "message" => "Ficha recusada não deve conter endereço ou famílias"
  }
)

upsert_rule!(
  record_type: "FAI",
  rule_code: "uuid_ficha_required",
  ledi_version: ledi_version,
  expression: {
    "type" => "present",
    "field_path" => "uuid_ficha",
    "message" => "UUID da ficha de atendimento individual é obrigatório"
  }
)

upsert_rule!(
  record_type: "FP",
  rule_code: "uuid_ficha_required",
  ledi_version: ledi_version,
  expression: {
    "type" => "present",
    "field_path" => "uuid_ficha",
    "message" => "UUID da ficha de procedimentos é obrigatório"
  }
)

upsert_rule!(
  record_type: "FV",
  rule_code: "uuid_ficha_required",
  ledi_version: ledi_version,
  expression: {
    "type" => "present",
    "field_path" => "uuid_ficha",
    "message" => "UUID da ficha de vacinação é obrigatório"
  }
)

upsert_rule!(
  record_type: "FCC",
  rule_code: "uuid_evolucao_required",
  ledi_version: ledi_version,
  expression: {
    "type" => "present",
    "field_path" => "uuid_evolucao",
    "message" => "UUID da evolução de cuidado compartilhado é obrigatório"
  }
)

{
  "FCI" => [
    %w[uuid string true],
    %w[tp_cds_origem integer true],
    %w[identificacao_usuario_cidadao.cpf_cidadao string false],
    %w[identificacao_usuario_cidadao.cns_cidadao string false],
    %w[identificacao_usuario_cidadao.nome_cidadao string false]
  ],
  "FCD" => [
    %w[uuid string true],
    %w[tp_cds_origem integer true],
    %w[endereco_local_permanencia.nome_logradouro string false]
  ],
  "FAI" => [
    %w[uuid_ficha string true],
    %w[tp_cds_origem integer true],
    %w[atendimentos_individuais array false]
  ],
  "FP" => [
    %w[uuid_ficha string true],
    %w[tp_cds_origem integer true]
  ],
  "FV" => [
    %w[uuid_ficha string true],
    %w[tp_cds_origem integer true]
  ]
}.each do |record_type, fields|
  fields.each do |field_path, data_type, required|
    upsert_field!(
      record_type: record_type,
      field_path: field_path,
      data_type: data_type,
      required: required,
      ledi_version: ledi_version,
      min_occurs: required ? 1 : 0
    )
  end
end

puts "  LEDI catalog seeded (#{LediValidationRule.count} rules, #{LediFieldCatalog.count} fields)"
