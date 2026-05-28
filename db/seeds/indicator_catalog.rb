# frozen_string_literal: true

METHODOLOGY_VERSION = "3493/2024" unless defined?(METHODOLOGY_VERSION)

def upsert_indicator!(code:, name:, funding_component:, team_kind:, display_order:, rule_code: "default")
  catalog = IndicatorCatalog.find_or_initialize_by(code: code)
  catalog.assign_attributes(
    name: name,
    funding_component: funding_component,
    team_kind: team_kind,
    methodology_version: METHODOLOGY_VERSION,
    periodicity: "quarterly",
    display_order: display_order,
    active: true
  )
  catalog.save!

  IndicatorRule.find_or_initialize_by(indicator_catalog: catalog, rule_code: rule_code).tap do |rule|
    rule.rule_kind = "good_practice"
    rule.expression = {
      "version" => "dsl_v1_stub",
      "indicator_code" => code,
      "methodology_version" => METHODOLOGY_VERSION,
      "status" => "seed_placeholder"
    }
    rule.save!
  end

  catalog
end

upsert_indicator!(
  code: "CVAT",
  name: "Componente de Avaliação Territorial",
  funding_component: "linkage",
  team_kind: "esf",
  display_order: 0
)

[
  [ "V_CAD", "Vínculo e acompanhamento — cadastro", "linkage", "esf", 1 ],
  [ "V_ACOMP", "Vínculo e acompanhamento — acompanhamento", "linkage", "esf", 2 ],
  [ "V_SAT", "Vínculo e acompanhamento — satisfação", "linkage", "esf", 3 ]
].each do |code, name, component, team_kind, order|
  upsert_indicator!(code: code, name: name, funding_component: component, team_kind: team_kind, display_order: order)
end

[
  [ "C1", "Mais acesso à APS", "quality", "esf", 10 ],
  [ "C2", "Cuidado no desenvolvimento infantil", "quality", "esf", 11 ],
  [ "C3", "Cuidado da gestante e puérpera", "quality", "esf", 12 ],
  [ "C4", "Cuidado da pessoa com diabetes", "quality", "esf", 13 ],
  [ "C5", "Cuidado da pessoa com hipertensão", "quality", "esf", 14 ],
  [ "C6", "Cuidado da pessoa idosa", "quality", "esf", 15 ],
  [ "C7", "Cuidado da mulher na prevenção do câncer", "quality", "esf", 16 ],
  [ "C8", "1ª consulta odontológica programada", "quality", "esb", 17 ],
  [ "C9", "Tratamento odontológico concluído", "quality", "esb", 18 ],
  [ "C10", "Exodontias", "quality", "esb", 19 ],
  [ "C11", "Escovação supervisionada", "quality", "esb", 20 ],
  [ "C12", "Procedimentos preventivos odontológicos", "quality", "esb", 21 ],
  [ "C13", "Tratamento restaurador atraumático", "quality", "esb", 22 ],
  [ "C14", "Média de atendimentos por pessoa", "quality", "emulti", 23 ],
  [ "C15", "Ações interprofissionais", "quality", "emulti", 24 ]
].each do |code, name, component, team_kind, order|
  upsert_indicator!(code: code, name: name, funding_component: component, team_kind: team_kind, display_order: order)
end

puts "  Indicator catalog: #{IndicatorCatalog.count} entries, #{IndicatorRule.count} rules"
