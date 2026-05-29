# ADR-0003: EPIC-05 fechamento em escopo MVP (Sprints 6–7)

## Status

Accepted — 2026-05-29 (revisão gate Fase 4: 2026-05-28)

## Context

O roteiro imediato S1–S7 exige entregar motor de indicadores e painel gestor no repo `cidadaobr`, com gate formal `phase-4-indicators: completed` quando regras eSB/eMulti estiverem operacionais.

## Decision

Fechar **Sprints 6–7 no `cidadaobr`** e marcar **`phase-4-indicators: completed`** com:

1. **DSL `dsl_v1` para B1–B6 (eSB) e M1–M2 (eMulti)** em `indicator_rules.expression`, com `source_ref` no pack [`lib/indicators/methodology/3493-2024/`](../../lib/indicators/methodology/3493-2024/) e merge via `Indicators::MethodologyLoader`.
2. **`care_teams.team_kind`** (`esf`, `eap`, `esb`, `emulti`, `municipality`) para filtrar regras em `RuleCatalog` sem depender só do fallback MVP.
3. **Repasse federal** permanece **ilustrativo** (`Indicators::Scoring::COMPONENT_BASE_BRL` + disclaimer na UI) até publicação de coeficientes oficiais da Portaria GM/MS 3.493/2024 — isso **não bloqueia** o gate Fase 4 após esta revisão.
4. Validação de regras clínicas contra LEDI/PEC em produção (ex.: V_SAT além de proxy `encounter_in_window`) continua como melhoria pós-MVP.

### Incluído no MVP

- DSL v1 para CVAT, V_CAD, V_ACOMP, V_SAT, C1–C7, **B1–B6, M1–M2**; recálculo Kafka incluindo `appointment.noshow`.
- B3 com `team_score_mode: procedure_ratio` (taxa de exodontias invertida em score 0–100); gaps por cidadão omitidos para B3 (`skip_citizen_gaps`).
- Painel X/N (indicadores com score no quadrimestre), ranking de equipes, gaps agrupados por indicador com filtro.
- Projeção de repasse ilustrativa com disclaimer na UI.
- Relatório web de ocupação/absenteísmo (`Scheduling::FacilityUtilizationReport`).

### Fora deste ADR (repos irmãos / fases posteriores)

- Apps Flutter (`cidadaobr-citizen`, `cidadaobr-field`) — Sprint 5.
- Conciliação SIAPS — EPIC-11.
- Coeficientes oficiais de repasse (substituir `COMPONENT_BASE_BRL`).

## Consequences

- Gestores veem **B1–M2 com score e gaps** (exceto B3, métrica só de equipe).
- Projeção de repasse continua **não oficial**; copy na UI deixa isso explícito.
- Gate Fase 5 (EPIC-06/07) pode prosseguir com `phase-4-indicators: completed`.
- TASK-09-09 (regras B/M) considerada entregue no escopo EPIC-05; refinamentos LEDI/PEC seguem em EPIC-09.
