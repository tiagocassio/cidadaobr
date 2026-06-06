# Decisão de roadmap — pós-piloto Fase 4

**Status:** Opção A — Fase 5 (EPIC-06/07) **gate técnico concluído** (jun/2026); UI gestor = checklist prefeitura  
**Estado atual (jun/2026):** [status-plano-2026-06.md](status-plano-2026-06.md) — entrada única PO/comercial  
**Plano mestre:** [padrão_ledi_e-sus_4f004208.plan.md](../padrão_ledi_e-sus_4f004208.plan.md) — HEAD `7f85332`  
**Gate técnico Fase 4/4b:** concluído — [ADR-0003](../adr/0003-epic05-mvp-scope.md), [ADR-0005](../adr/0005-methodology-coverage.md)

---

## Onde estamos

| Marco | Status |
|-------|--------|
| Motor 17 indicadores (B1–M2) | Entregue (MVP + packs EPIC-05b) |
| Painel gestor + gaps + ranking | Entregue |
| Cobertura normativa BPs | **53/53 `done`** — [matriz](../indicators/methodology-coverage-matrix.md); C2.E PNI Onda 2a — [ADR-0009](../adr/0009-pni-calendar-reference.md) |
| V_SAT (satisfação) | Entregue — `TeamSatisfactionSurveyScore` + `ImportSatisfactionSurvey` |
| Repasse em R$ | **Ilustrativo** (TASK-05-07) |
| `phase-4-indicators` | completed |
| `phase-4b-methodology` | completed |
| `phase-5-field-campaigns` | **completed** (gate técnico) — suite RSpec verde; E2E HTTP; UI gestor no checklist prefeitura |
| EPIC-12 (referência MS) | **done (gate)** — `Reference::Gate`, `bin/ci_reference_gate`; stretch UFSC/DATASUS |

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

- [x] **Opção A — Fase 5:** `phase-5-field-campaigns` → `completed` (gate técnico jun/2026; UI gestor = checklist prefeitura)
- [ ] **Opção B — Credibilidade:** TASK-05-07 + EPIC-11
- [ ] **Opção C — Paralelo:** EPIC-06/07 + TASK-05-07
- [ ] **Opção D — Mobile first:** descartada — Flutter só Fase 8

**Próximo passo:** **Fase 7** (EPIC-11 IA/SIAPS) → **Fase 8** (Flutter). Piloto: [piloto-validacao-tecnica.md](piloto-validacao-tecnica.md). — [status-plano-2026-06.md](status-plano-2026-06.md).

---

## Limitações MVP (EPIC-06/07)

- **Vacina:** aprovação desconta doses comprometidas em outras campanhas; **não reserva nem baixa estoque físico** no MVP.
- **Domiciliar:** rollup na publicação de rotas; campanha `scheduled` só sem rotas em rascunho.
- **Rotas:** nearest-neighbor + clustering PostGIS; TSP ótimo pós-gate.
