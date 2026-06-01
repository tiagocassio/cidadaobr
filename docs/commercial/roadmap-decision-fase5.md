# Decisão de roadmap — pós-piloto Fase 4

**Status:** Opção A — Fase 5 (EPIC-06/07) em andamento; specs E2E ok; **gate UI piloto pendente** (jun/2026)  
**Status consolidado:** [status-plano-2026-06.md](status-plano-2026-06.md)  
**Plano mestre:** [padrão_ledi_e-sus_4f004208.plan.md](../padrão_ledi_e-sus_4f004208.plan.md) — HEAD `6949e68`  
**Gate técnico Fase 4/4b:** concluído — [ADR-0003](../adr/0003-epic05-mvp-scope.md), [ADR-0005](../adr/0005-methodology-coverage.md)

---

## Onde estamos

| Marco | Status |
|-------|--------|
| Motor 17 indicadores (B1–M2) | Entregue (MVP + packs EPIC-05b) |
| Painel gestor + gaps + ranking | Entregue |
| Cobertura normativa BPs | **52/53 `done`** — [matriz](../indicators/methodology-coverage-matrix.md); 1 `partial` (C2.E) |
| V_SAT (satisfação) | Entregue — `TeamSatisfactionSurveyScore` + `ImportSatisfactionSurvey` |
| Repasse em R$ | **Ilustrativo** (TASK-05-07) |
| `phase-4-indicators` | completed |
| `phase-4b-methodology` | completed |
| `phase-5-field-campaigns` | **in_progress** — código + specs gate ok (`6949e68`, 21 ex.); **piloto UI** pendente |
| EPIC-12 (referência MS) | **partial** — jobs + API `/reference/*`; release versionada pendente |

---

## Trilhas disponíveis

| Trilha | EPIC / TASK | Quando priorizar | Esforço |
|--------|-------------|------------------|---------|
| **Operação de massa** | EPIC-06 → EPIC-07 → gate F5 → EPIC-09 | Piloto: campanha, visita, PEC | Grande |
| **Dados de referência** | EPIC-12 S8–S9 | Antes de Fase 6 clínica (combos) | Médio — pode paralelizar gate F5 |
| **Credibilidade financeira** | TASK-05-07, EPIC-11 | Secretário exige número = MS | Médio — paralelo |
| **Apps mobile** | Fase 8 | Após Fases 5–7 web | Grande |

---

## Decisão registrada

- [x] **Opção A — Fase 5:** `phase-5-field-campaigns` → `in_progress` (2026-05-28)
- [ ] **Opção B — Credibilidade:** TASK-05-07 + EPIC-11
- [ ] **Opção C — Paralelo:** EPIC-06/07 + TASK-05-07
- [ ] **Opção D — Mobile first:** descartada — Flutter só Fase 8

**Próximo passo:** (1) ~~specs gate~~ ok 2026-06-01; **(2) piloto UI Fase 5**; (3) marcar EPIC-06/07 + `phase-5` completed. Paralelo: EPIC-12. PNI: onda 2 — [status-plano-2026-06.md](status-plano-2026-06.md).

---

## Limitações MVP (EPIC-06/07)

- **Vacina:** aprovação desconta doses comprometidas em outras campanhas; **não reserva nem baixa estoque físico** no MVP.
- **Domiciliar:** rollup na publicação de rotas; campanha `scheduled` só sem rotas em rascunho.
- **Rotas:** nearest-neighbor + clustering PostGIS; TSP ótimo pós-gate.
