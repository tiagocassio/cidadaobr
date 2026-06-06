# ADR-0004: Fontes de dados de referência MS/LEDI

## Status

Accepted — EPIC-12 (S8–S9), extends [ADR-0009](0009-pni-calendar-reference.md) for PNI calendars

## Context

Formulários clínicos, walk-in web e indicadores dependem de domínios versionados (CIAP-2, CID-10, SIGTAP, catálogo LEDI, calendário PNI). O MVP usou seeds manuais e HTML ao vivo da UFSC. EPIC-12 centraliza ingestão em Postgres global (`reference_*`) com releases auditáveis (`reference_data_releases`).

Produção municipal exige atualização periódica (SIGTAP mensal, PNI anual, LEDI por versão) sem acoplar runtime a scraping ao vivo. **Versão LEDI alvo:** 7.4.1 (`config/ledi.yml`, `vendor/ledi/7.4.1/`); competência SIGTAP default **202602** (alinhada à release 7.4.1).

## Decision

1. **SSOT runtime:** PostgreSQL global — `reference_domains`, `reference_domain_entries`, `ledi_field_catalogs`, `pni_schedule_entries`, manifest em `reference_data_releases`.

2. **Fixture-first em CI:** [`vendor/reference/domains.yml`](../../vendor/reference/domains.yml) é a fonte determinística para testes e ambientes offline. `Reference::DomainSeedImporter` prefere `vendor/` sobre `db/seeds/reference/`. Variável `REFERENCE_USE_DB_SEED=1` força seed local.

3. **Jobs recorrentes (produção):** [`config/recurring.yml`](../../config/recurring.yml) — `UfscReferenceImportJob` (dia 1), `LediCatalogSyncJob` (dia 1), `SigtapImportJob` (dia 5), `PublishReferenceReleaseJob` (dia 5, `Gate.publish_release!` após SIGTAP). Bootstrap offline: `db:seed` ou `rake reference:gate`. MVP importa fixtures/YAML; **stretch** substitui por feed UFSC/DATASUS sem mudar contrato de release.

4. **Publicação:** `Reference::Commands::PublishRelease` via `CommandBus` — checksum SHA-256, evento `reference-release-published` (platform outbox, [ADR-0008](0008-platform-scoped-outbox.md)).

5. **Consumo:** API `GET /api/v1/reference/*` (JWT gestor/field); web gestão usa leitura direta ou autocompletes Stimulus (TASK-12-07). Apps Flutter (Fase 8) sincronizam por manifest/ETag. **Release ativa** (`Reference::ActiveRelease`) é global à plataforma na Fase 6; pinning por município fica para fases futuras.

6. **Gate CI:** `bin/ci_reference_gate` executa cadeia import → catálogo → PNI (se vazio) → publish → validação de manifest ([`Reference::Gate`](../../lib/reference/gate.rb)).

## Consequences

- SIGTAP real (download DATASUS) — `Reference::SigtapRemoteFetcher` com fallback fixture; ativar produção com `SIGTAP_LIVE=1` (CI/test usam fixture).
- Catálogo LEDI automático — `Reference::LediCatalogVendorParser` lê `vendor/ledi/{version}/gen-rb/` antes do seed.
- PNI: SOT Ruby ([`PniCalendarDefinitions`](../../lib/reference/pni_calendar_definitions.rb)); JSON export auditável não versionado (`.gitignore`).
- EPIC-12 **bloqueia Fase 6 clínica** até gate CI + release reproduzível passarem.

## References

- [padrão_ledi_e-sus_4f004208.plan.md](../padrão_ledi_e-sus_4f004208.plan.md) § EPIC-12
- [status-plano-2026-06.md](../commercial/status-plano-2026-06.md)
- `lib/reference/commands/publish_release.rb`
- `spec/lib/reference/gate_spec.rb`
