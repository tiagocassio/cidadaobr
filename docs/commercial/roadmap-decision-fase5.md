# Decisão de roadmap — pós-piloto Fase 4

**Status:** Opção A registrada — EPIC-06 (estoque + campanhas) em andamento (maio/2026)  
**Gate técnico:** Fase 4 concluída — ver [ADR-0003](../adr/0003-epic05-mvp-scope.md)

---

## Onde estamos

| Marco | Status |
|-------|--------|
| Motor 17 indicadores (B1–M2) | Entregue |
| Painel gestor + gaps + ranking | Entregue |
| Repasse em R$ | **Ilustrativo** (TASK-05-07 pendente) |
| `phase-4-indicators` | completed no plano mestre |
| `phase-5-field-campaigns` | **in_progress** — Opção A (EPIC-06 kickoff) |

---

## Trilhas disponíveis

| Trilha | EPIC / TASK | Quando priorizar | Esforço relativo |
|--------|-------------|------------------|------------------|
| **Operação de massa** | EPIC-06 → EPIC-07 → EPIC-09 (web) | Piloto pede campanha, visita domiciliar, PEC | Grande (Fases 5–6 web) |
| **Credibilidade financeira** | TASK-05-07, EPIC-11 (SIAPS) | Secretário exige “número igual ao MS” | Médio — pode correr em paralelo |
| **Apps mobile** | **Fase 8** — mobile-shared, Citizen, Field | Lojas / profissionais de campo / autogestão cidadão | Grande — **após Fases 5–7 web** |

---

## Recomendação alinhada ao plano mestre

Após piloto validado com checklist ([checklist-piloto-prefeitura.md](checklist-piloto-prefeitura.md)):

1. **Default técnico:** iniciar **EPIC-06** (estoque + campanha vacina) — próximo bloco sequencial em [plano mestre](../padrão_ledi_e-sus_4f004208.plan.md) (STORY-06-01, STORY-06-02).
2. **Paralelo opcional:** TASK-05-07 (coeficientes oficiais de repasse) se houver pressão comercial por credibilidade financeira.
3. **Não bloquear Fase 5** por SIAPS — trilhas são independentes após gate Fase 4.

---

## Ação quando decidir

Marque a opção escolhida e atualize o [plano mestre](../padrão_ledi_e-sus_4f004208.plan.md):

- [x] **Opção A — Fase 5 (EPIC-06):** `phase-5-field-campaigns` → `in_progress`
- [ ] **Opção B — Credibilidade (TASK-05-07 + EPIC-11):** documentar ADR ou epic dedicado
- [ ] **Opção C — Paralelo:** EPIC-06 in_progress + TASK-05-07 em sprint paralelo
- [ ] **Opção D — Mobile first:** ~~EPIC-04 antes de EPIC-06~~ **descartada (2026-05-29)** — apps Flutter só na **Fase 8**

**Decisão registrada:** Opção A — iniciar EPIC-06 (estoque + campanhas de vacinação) como trilha padrão pós-gate Fase 4; TASK-05-07 e SIAPS permanecem paralelos opcionais.  
**Data:** 2026-05-28  
**Responsável:** PO (default técnico alinhado ao plano mestre)

### Limitações MVP (EPIC-06)

- **Provisionamento de vacina:** aprovação desconta doses já comprometidas por outras campanhas `provisioning_approved`/`scheduled`/`active` no mesmo imunobiológico e unidade, mas **não reserva nem decrementa estoque físico** — reserva dura e baixa no ato da aplicação ficam para pós-MVP.
- **Campanha domiciliar:** rollup de provisionamento roda na geração/publicação de rotas; publicação exige status `calculated` (rollup recente). Campanhas só vão para `scheduled` quando não restam rotas em rascunho.
