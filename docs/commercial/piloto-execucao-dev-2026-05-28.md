# Execução do piloto — ambiente dev (2026-05-28)

Registro da validação técnica automatizada e dos critérios do [checklist-piloto-prefeitura.md](checklist-piloto-prefeitura.md) executáveis sem UI manual.

## Ambiente

```bash
docker compose up -d postgres
bin/rails db:migrate
bin/rails db:seed
```

## Critérios verificados (automático)

| Critério | Resultado |
|----------|-----------|
| 4 equipes tipadas (ESF×2, eSB×1, eMulti×1) | OK — INE 0000000001..0000000004 |
| Catálogo Portaria 3.493 ativo | OK — 19 indicadores, 21 regras DSL (incl. V_CAD_ATU / V_LIM_CAD) |
| Legacy desativado no seed | OK — 8 entradas inativas fora da Portaria |
| Estoque demo (EPIC-06) | OK — 1 imunobiológico, 1 lote (UBS Centro) |
| Suite indicadores + inventário | OK — 66 examples, 0 failures |
| Gaps filtrados por `active_portaria` no painel | OK — controllers dashboard/teams |

## Comandos de teste

```bash
bundle exec rspec spec/lib/indicators/ spec/lib/inventory/ spec/models/indicator* spec/db/indicator_catalog_seed_spec.rb
```

### Gate Fase 5 (campanhas — 2026-06-01)

```bash
bundle exec rspec spec/requests/web/stock_and_campaigns_spec.rb spec/lib/inventory/reserve_visit_route_supplies_spec.rb
```

Resultado esperado: **21 examples, 0 failures** (inclui E2E HTTP domiciliar + wizard vacina).

Correção aplicada: `Web::Campaigns::HomeVisitCampaignsController` usa `::Campaigns::Commands::BuildCampaignTargetList` (evita `NameError` em `build_targets`).

## Checklist manual pendente (UI)

Itens 1–8 de [piloto-validacao-tecnica.md](piloto-validacao-tecnica.md) requerem login web:

- `admin@cidadaobr.local` / `password123`
- `ubs.centro@cidadaobr.local` / `password123`

Rotas EPIC-06 adicionadas:

- `/web/stock/immunobiological_lots`
- `/web/campaigns/vaccination_campaigns`

## Decisão Fase 5

Opção A registrada em [roadmap-decision-fase5.md](roadmap-decision-fase5.md) — EPIC-06 kickoff (schema, `ProvisioningValidator`, WEB-STOCK/CAMP).

## Semanas 0–12 (comercial)

Execução presencial na prefeitura piloto segue [checklist-piloto-prefeitura.md](checklist-piloto-prefeitura.md) — fora do escopo desta validação dev.
