# Migrar C3.K de calendário fixo (9 meses) para janela gestacional

**Labels:** `indicators`, `methodology`, `c3`, `backlog`  
**Epic:** EPIC-05b / ADR-0005 (methodology coverage)

## Contexto

C3 B–H passaram a usar `GestationalAnchor` com janela gestacional 0–42 semanas a partir da DUM ancorada (`gestational_evidence_count_gte`, `gestational_clinical_predicate`, etc.). **C3.K** ainda usa `within_months: 9` em `clinical_predicate` sobre FAO — calendário fixo, não alinhado ao ciclo gestacional.

Ver: `docs/indicators/gestational-anchor.md`, packs `C3.K.json` e definição em `methodology_pack_definitions.rb` (regra `"K"`).

## Problema

- Gestantes com DUM no início do quadrimestre podem ter janela de 9 meses **maior** que a gestação real.
- Gestantes com gestação encerrada no lookback retroativo podem ser avaliadas com janela errada vs B–H.
- Inconsistência metodológica dentro do indicador C3.

## Proposta

1. Definir numerador C3.K na Portaria/nota técnica (o que exatamente mede em FAO).
2. Migrar pack + `methodology_pack_definitions` para resolver gestacional (ex.: `gestational_clinical_predicate` ou equivalente com `active_only: false`, `min/max_gestational_weeks`).
3. Specs de integração retroativa (padrão C3-H).
4. Atualizar `methodology-coverage-matrix.md`.

## Critérios de aceite

- [ ] C3.K não usa `within_months: 9` como proxy de gestação.
- [ ] Ancoragem via DUM + parto pareado (mesmas regras de `GestationalAnchor`).
- [ ] Specs verdes em `spec/lib/indicators/dsl_v1/evaluator_spec.rb`.
- [ ] `rails indicators:audit_coverage` sem `missing_resolvers`.

## Follow-ups relacionados (fora do escopo desta issue)

- Parto documentado fora de FAI não fecha janela (`delivery_for_dum` só FAI) — documentado em `gestational-anchor.md`; avaliar outros `record_types` se LEDI permitir.
- `latest_dum`: DUM fantasma pós-parto sem `ended_pregnancy_dum` ainda pode vencer via fallback `active.max` — edge case de qualidade de dado.

## Referências

- ADR-0005: `docs/adr/0005-methodology-coverage.md`
- Commit gestational anchor (C3 B–H): branch `feat/c3-gestational-anchor`
