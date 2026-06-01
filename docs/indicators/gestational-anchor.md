# Ancoragem gestacional (C3 A–H)

Referência de implementação: [`GestationalAnchor`](../../lib/indicators/dsl_v1/resolvers/gestational_anchor.rb) e resolvers clínicos em [`ClinicalEvidence`](../../lib/indicators/dsl_v1/resolvers/clinical_evidence.rb).

## Janela gestacional vs calendário fixo

Bps C3 B–E usam `gestational_evidence_count_gte` com semanas **0–42** a partir da DUM ancorada, não `within_months: 9`. C3 E exige visitas **após a 1ª consulta pré-natal** (FAI com `atendimentos_individuais`), sem teto de 12 semanas (isso é só C3 A).

## `latest_dum`

| Modo | Uso | Comportamento |
|------|-----|----------------|
| `active_only: true` (default em `records_in_gestational_window`) | Indicadores que exigem gestação/puerpério **na data de referência** | DUM do ciclo após o último parto, com `reference_date` dentro de gestação + 42d puerpério |
| `active_only: false` | C3 A–H (auditoria retroativa no quadrimestre) | (1) DUM de ciclo ativo na `reference_date`, senão (2) DUM pareado ao último parto no lookback, senão (3) DUM mais recente ≤ `reference_date` no lookback (15 meses) |

Constante compartilhada: `GestationalAnchor::RETROSPECTIVE_ACTIVE_ONLY_DEFAULT` (`false`) — aplicada em B–H e em `first_prenatal_consult_date` quando o pack não sobrescreve.

### Qualidade de dado

DUM registrada **após** um parto pareado, sem novo `dataParto` correspondente, **não** substitui o DUM da gestação encerrada: em `active_only: false`, DUMs pós-parto sem parto pareado são descartadas antes de escolher o ciclo ativo; sobra `ended_pregnancy_dum` ou candidatos ≤ `reference_date`.

## Parto e pós-parto

- **`delivery_for_dum`**: parto inferido só de **FAI** (campos LEDI `dataParto`, etc.), pareado ao ciclo da DUM (`delivery >= dum`, `delivery - dum <= 280`, `delivery <= reference_date`).
- **`exclude_after_delivery: true`**: exclui encontros com `encounter_date >= delivery` (inclui o dia do parto na janela gestacional; alinhado a C3 I, que usa `> delivery` no puerpério).
- Parto **após** `reference_date`: não corta a janela — gestação em curso na data de cálculo.
- **Backlog**: parto documentado fora de FAI não fecha a janela (superestimação possível).

## 1ª consulta pré-natal

`first_prenatal_consult_date` usa `active_only: false`, filtra consultas `>= dum`, exclui encontros `>= delivery` quando há parto pareado, e só aplica teto de semanas quando o pack define `max_weeks` (C3 A: ≤12 sem).

## Contagem de evidências

`gestational_evidence_count_gte` conta **registros clínicos** (encontros), não payloads aninhados — alinhado a “7 consultas / 7 aferições” na gestação.

Medidas válidas: `consult`, `visit`, `blood_pressure`, `anthropometry`. `consult` e `visit` exigem `predicate` no pack (validado em `CoverageAudit`).

## Bps C3 por resolver

| BP | Resolver | `active_only` |
|----|----------|---------------|
| A | `first_prenatal_consult` | false (via `first_prenatal_consult_date`) |
| B–E | `gestational_evidence_count_gte` | false |
| F | `gestational_vaccination_immunobiologic` | false |
| G–H | `gestational_clinical_predicate` | false |
| I–J | `puerperium_*` | N/A (janela pós-parto) |
