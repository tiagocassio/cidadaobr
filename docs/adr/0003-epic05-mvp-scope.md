# ADR-0003: EPIC-05 fechamento em escopo MVP (Sprints 6–7)

## Status

Accepted — 2026-05-29

## Context

O roteiro imediato S1–S7 exige entregar motor de indicadores e painel gestor no repo `cidadaobr`, com gate formal `phase-4-indicators: completed` apenas quando regras e repasse estiverem alinhados à Portaria GM/MS 3.493/2024.

## Decision

Fechar **Sprints 6–7 no `cidadaobr`** com critério **MVP**, mantendo EPIC-05 como **parcial** no plano até:

1. DSL completo para **C8–C15** (eSB/eMulti) — hoje `stub_expression` no seed.
2. Coeficientes oficiais de repasse (substituir `Indicators::Scoring::COMPONENT_BASE_BRL`).
3. Validação de regras clínicas contra LEDI/PEC em produção (ex.: V_SAT além de proxy `encounter_in_window`).

### Incluído no MVP

- DSL v1 para CVAT, V_CAD, V_ACOMP, V_SAT, C1–C7; recálculo Kafka incluindo `appointment.noshow`.
- Painel X/N (indicadores com score no quadrimestre), ranking de equipes, gaps agrupados por indicador com filtro.
- Projeção de repasse ilustrativa com disclaimer na UI.
- Relatório web de ocupação/absenteísmo (`Scheduling::FacilityUtilizationReport`).

### Fora deste ADR (repos irmãos / fases posteriores)

- Apps Flutter (`cidadaobr-citizen`, `cidadaobr-field`) — Sprint 5.
- Conciliação SIAPS — EPIC-11.

## Consequences

- Gestores podem operar com projeção **não oficial**; copy na UI deixa isso explícito.
- C8–C15 aparecem no catálogo mas não movem score até regras reais.
- Gate Fase 5 (EPIC-06/07) permanece bloqueado até `phase-4-indicators: completed` ou revisão explícita do gate.
