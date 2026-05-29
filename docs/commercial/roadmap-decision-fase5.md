# Decisão de roadmap — pós-piloto Fase 4

**Status:** aguardando decisão do CEO (maio/2026)  
**Gate técnico:** Fase 4 concluída — ver [ADR-0003](../adr/0003-epic05-mvp-scope.md)

---

## Onde estamos

| Marco | Status |
|-------|--------|
| Motor 17 indicadores (B1–M2) | Entregue |
| Painel gestor + gaps + ranking | Entregue |
| Repasse em R$ | **Ilustrativo** (TASK-05-07 pendente) |
| `phase-4-indicators` | completed no plano mestre |
| `phase-5-field-campaigns` | pending — **próximo gate** |

---

## Trilhas disponíveis

| Trilha | EPIC / TASK | Quando priorizar | Esforço relativo |
|--------|-------------|------------------|------------------|
| **Operação de massa** | EPIC-06 → EPIC-07 → EPIC-08 | Piloto pede campanha, visita domiciliar, app campo | Grande (Fase 5 padrão no plano) |
| **Credibilidade financeira** | TASK-05-07, EPIC-11 (SIAPS) | Secretário exige “número igual ao MS” | Médio — pode correr em paralelo |
| **Canal cidadão** | EPIC-04 / Sprint 5 | Proposta comercial exige app munícipe | Médio — API já existe |

---

## Recomendação alinhada ao plano mestre

Após piloto validado com checklist ([checklist-piloto-prefeitura.md](checklist-piloto-prefeitura.md)):

1. **Default técnico:** iniciar **EPIC-06** (estoque + campanha vacina) — próximo bloco sequencial em [plano mestre](../padrão_ledi_e-sus_4f004208.plan.md) (STORY-06-01, STORY-06-02).
2. **Paralelo opcional:** TASK-05-07 (coeficientes oficiais de repasse) se houver pressão comercial por credibilidade financeira.
3. **Não bloquear Fase 5** por SIAPS — trilhas são independentes após gate Fase 4.

---

## Ação quando decidir

Marque a opção escolhida e atualize o [plano mestre](../padrão_ledi_e-sus_4f004208.plan.md):

- [ ] **Opção A — Fase 5 (EPIC-06):** `phase-5-field-campaigns` → `in_progress`
- [ ] **Opção B — Credibilidade (TASK-05-07 + EPIC-11):** documentar ADR ou epic dedicado
- [ ] **Opção C — Paralelo:** EPIC-06 in_progress + TASK-05-07 em sprint paralelo
- [ ] **Opção D — Cidadão primeiro:** EPIC-04 antes de EPIC-06

**Decisão registrada:** _pendente_  
**Data:** _—_  
**Responsável:** _CEO / PO_
