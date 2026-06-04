# ADR-0009: Calendário PNI versionado para indicadores

## Status

Accepted — extends [ADR-0005](0005-methodology-coverage.md) and EPIC-12 reference data

## Context

BP **C2.E** (vacinação calendário infantil 0–2 anos, Portaria 3.493) exigia calendário técnico MS integral. O MVP usou proxy hardcoded em `VaccinationCalendar` com match por nome na FV — insuficiente para auditoria (código PNI, dose, janela etária).

O MS publica calendários por faixa etária (Normal + Técnico), revisados anualmente. Apenas **C2.E** exige calendário integral no cofinanciamento APS; demais BPs vacinais (C3.F dTpa, C6.D influenza, C7.C HPV) são regras pontuais já `done`.

## Decision

1. **SOT em Ruby:** `Reference::PniCalendarDefinitions` — curadoria anual contra calendário técnico MS (como `MethodologyPackDefinitions`).

2. **Export auditável:** `lib/reference/pni/{year}/*.json` — gerado por `CommandBus.dispatch(Reference::Commands::SyncPniCalendar, export_json: true)`; **não** lido em runtime. Arquivos JSON ficam fora do git (`.gitignore`); validar com `reference:pni:audit`.

3. **Runtime DB:** tabela global `pni_schedule_entries` (sem tenant), populada por `Reference::Commands::SyncPniCalendar` (rake `reference:pni:sync`, job `ImportPniCalendar`).

4. **Releases:** `Reference::Commands::PublishRelease` inclui bloco `pni_calendars` no `manifest_json`; snapshots de equipe gravam `pni_calendar_release_key` em `team_indicator_results.metadata_json`.

5. **Nomenclatura en-US:** `immunobiological_*` em schema, models e export. Campos LEDI/FV em português (`imunobiologico`, `codigoImunobiologico`) só na camada de payload.

6. **Motor:** `Indicators::PniScheduleEvaluator` — release vigente, doses exigíveis por idade na `reference_date`, match código + dose em `citizen_immunization_records` ou FV.

7. **Onda 2a (esta entrega):** `age_group` `child`, escopo 0–24 meses (C2.E). Ondas 2b–2d reutilizam a mesma infraestrutura.

## Consequences

- Proxy `REQUIRED_BY_MAX_AGE_MONTHS` removido; C2.E → `done` na matriz de cobertura.
- Atualização anual: PR em `PniCalendarDefinitions` → `bin/rails reference:pni:sync` → `reference:pni:audit` → `reference:pni:recalculate_indicators` (async, um job por município; worker obrigatório).
- `CitizenImmunizationProjector` projeta `vacinacoes[].vacinas[]` LEDI antes do evaluator (projeção LEDI read-model; `save!` local sem CommandBus — exceção documentada, sem evento de integração).
- Tabela global `pni_schedule_entries` sem RLS tenant (referência MS); acesso via role app com políticas default do cluster.
- CRIE/RIE permanecem fora do denominador rotineiro C2.E (onda futura).

## References

- [status-plano-2026-06.md](../commercial/status-plano-2026-06.md) §3
- [methodology-coverage-matrix.md](../indicators/methodology-coverage-matrix.md)
- `lib/reference/pni_calendar_definitions.rb`
- `lib/reference/pni_calendar_loader.rb`
- `lib/indicators/pni_schedule_evaluator.rb`
