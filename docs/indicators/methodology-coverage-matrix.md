# Matriz de cobertura — Notas Metodológicas (Portaria 3.493 / SAPS)

Documento vivo: compara requisitos oficiais com implementação no motor `dsl_v1`.
Atualizado conforme definições em [`lib/indicators/methodology_pack_definitions.rb`](../../lib/indicators/methodology_pack_definitions.rb) (SOT), export em [`lib/indicators/methodology/3493-2024/packs/`](../../lib/indicators/methodology/3493-2024/packs/) e resolvers em [`lib/indicators/dsl_v1/resolvers/`](../../lib/indicators/dsl_v1/resolvers/).

**Snapshot (2026-05-31, onda 2 ADR-0005):** **52 / 53 `done`** · **1 `partial`** (C2.E PNI proxy) · 0 `external` · 0 `todo`

## Fontes normativas

| Documento | URL |
|-----------|-----|
| Nota Técnica 30/2025 (CVAT) | [eSF/eAP SAPS](https://www.gov.br/saude/pt-br/composicao/saps/publicacoes/fichas-tecnicas/equipe-de-atencao-primaria-e-saude-da-familia) |
| Notas C1–C7 | mesma página |
| B1–B6 | [eSB](https://www.gov.br/saude/pt-br/composicao/saps/publicacoes/fichas-tecnicas/equipe-de-saude-bucal) |
| M1–M2 | [eMulti](https://www.gov.br/saude/pt-br/composicao/saps/publicacoes/fichas-tecnicas/equipes-multiprofissionais-emulti) |

## Legenda de status

| Status | Significado |
|--------|-------------|
| `done` | Regra pack + resolver + spec |
| `partial` | Proxy ou subconjunto da nota |
| `todo` | Pack definido, resolver pendente |
| `external` | Depende de dado fora LEDI (ex.: pesquisa SAT, SIAPS) |

## Componente II — Vínculo (CVAT, V-*)

| Indicador | BP | Denominador MS | Numerador MS | Fichas | Resolver | Status |
|-----------|-----|----------------|--------------|--------|----------|--------|
| V_CAD | V_CAD_COM | Vinculados à equipe | MICI + MICDT válidos (FCI + FCD) | FCI, FCD | `mici_micdt_complete` | done — FCI completa obrigatória (sem fallback municipal) |
| V_CAD | V_CAD_ATU | Vinculados | MICI revisado 24 meses | FCI | `fci_updated_within` | done — exige `dataAtualizacao` na FCI |
| V_CAD | V_LIM_CAD | Vinculados | Cadastros ≤ teto equipe | — | `registration_within_team_limit` + cap tier CVAT | done |
| V_ACOMP | V_ACOMP_12M | Vinculados | >1 contato e ≥1 atendimento / 12m | FAI, FAO, FP, FVD, FAC, FV, MCA | `contact_and_attendance` | done |
| V_SAT | V_SAT | Vinculados | Pesquisa satisfação MS | — | `satisfaction_survey` + import `TeamSatisfactionSurveyScore` | done |
| CVAT | — | Agregado | 3 pts CAD + 7 pts ACOMP + bônus SAT (0–10) | — | `linkage_aggregate` + `linkage_monthly_average` + `score_scale: ms_0_10` | done |

### Critérios transversais CVAT (NT 30/2025)

| Critério | População | Ficha | Status |
|----------|-----------|-------|--------|
| PBF | Beneficiário Bolsa Família | FCI | done — `fci_flag_present` (`pbf`) |
| BPC | Beneficiário BPC | FCI | done — `fci_flag_present` (`bpc`) |
| <5 anos | Crianças | FCI | done — `citizens_age_lte` |
| ≥60 anos | Idosos | FCI | done — `citizens_age_gte` |
| Vínculo INE/microárea | Adscrição | FCI, FCD | done — `microarea_linked` (micro FCI = micro FCD) |

## Componente III — Qualidade C1–C7

| Indicador | BP | Resumo numerador | Janela | Fichas | Status |
|-----------|-----|------------------|--------|--------|--------|
| C1 | A | Proporção atendimentos programados | quadrimestre | FAI, FP | done — `programmed_attendance_ratio` |
| C2 | A | 1ª consulta ≤30º dia | 30d | FAI | done |
| C2 | B | ≥9 consultas até 2 anos | 24m | FAI | done |
| C2 | C | ≥9 registros peso+altura | 24m | FAI, FVD, FAC | done |
| C2 | D | 2 visitas ACS (1ª ≤30d, 2ª ≤6m) | 6m | FVD | done — `acs_two_visit_schedule` |
| C2 | E | Vacinação calendário | 24m | FV | `vaccination_calendar` (PNI proxy 0–24m) | partial |
| C3 | A | 1ª consulta pré-natal ≤12 sem | gestação | FAI | done — `first_prenatal_consult` (`active_only: false`; `atendimentos_individuais`) |
| C3 | B | ≥7 consultas gestação | gestação | FAI | done — `gestational_evidence_count_gte` (`measure: consult`; 0–42 sem; exclui pós-parto) |
| C3 | C | ≥7 aferições PA | gestação | FAI, FP, FVD | done — `gestational_evidence_count_gte` (`measure: blood_pressure`; 0–42 sem) |
| C3 | D | ≥7 peso+altura | gestação | FAI, FVD, FP | done — `gestational_evidence_count_gte` (`measure: anthropometry`; 0–42 sem) |
| C3 | E | ≥3 visitas ACS pós 1ª consulta | gestação | FVD | done — `gestational_evidence_count_gte` (`after_first_prenatal`; 1ª FAI sem teto 12 sem; `motivosVisita`) |
| C3 | F | dTpa ≥20ª semana | gestação | FV | done — `gestational_vaccination_immunobiologic` (≥20ª sem; `active_only: false`) |
| C3 | G | Testes 1º trimestre | gestação | FAI | done — `gestational_clinical_predicate` (0–13 sem; `active_only: false`) |
| C3 | H | Testes 3º trimestre | gestação | FAI | done — `gestational_clinical_predicate` (28–42 sem; `active_only: false`) |
| C3 | I | ≥1 consulta puerpério | 42d pós-parto | FAI | done — `puerperium_consult` + `atendimentos_individuais` |
| C3 | J | ≥1 visita ACS puerpério | puerpério | FVD | done — `puerperium_visit` |
| C3 | K | ≥1 avaliação odontológica | gestação | FAO | done — `gestational_clinical_predicate` (0–42 sem; `active_only: false`) |
| C4 | A | ≥1 consulta médica/enfermagem | 6m | FAI | done |
| C4 | B | ≥1 aferição PA | 6m | FAI, FP, FVD | done |
| C4 | C | ≥2 visitas domiciliares ≥30d intervalo | 12m | FVD | done |
| C4 | D | ≥1 peso+altura | 12m | FAI, FP, FVD | done |
| C4 | E | ≥1 hemoglobina glicada | 12m | FAI | done — `clinical_predicate` / `procedure_present` (`0202010503`) |
| C4 | F | ≥1 avaliação dos pés | 12m | FAI, FP | done |
| C5 | A | ≥1 consulta | 6m | FAI | done |
| C5 | B | ≥1 aferição PA | 6m | FAI, FP, FVD | done |
| C5 | C | ≥2 visitas domiciliares | 12m | FVD | done |
| C5 | D | ≥1 peso+altura | 12m | FAI, FP, FVD | done |
| C6 | A | ≥1 consulta | 12m | FAI, FAD | done |
| C6 | B | ≥2 registros peso+altura | 12m | FAI, FP, FVD | done |
| C6 | C | ≥2 visitas domiciliares | 12m | FVD | done |
| C6 | D | ≥1 dose influenza | 12m | FV | done — `vaccination_immunobiologic` |
| C7 | A | Rastreamento colo do útero | 36m | FAI, FP | done |
| C7 | B | Rastreamento mama | 50–69a | FAI, FP | `citizens_age_between` + procedimento mama | done |
| C7 | C | Vacinação HPV | 9–14a | FV | `citizens_age_between` + `vaccination_immunobiologic` HPV | done |

Score C1–C7: `team_score_mode: good_practices_pct` quando há múltiplas BPs por indicador.

Detalhes de DUM, parto pareado e auditoria retroativa C3 A–H: [gestational-anchor.md](gestational-anchor.md).

## eSB B1–B6 e eMulti M1–M2

| Código | BP | Status | Notas |
|--------|-----|--------|-------|
| B1 | B1 | done | FAO 1ª consulta programática |
| B2 | B2 | done | Tratamento concluído |
| B3 | B3 | done | `procedure_ratio` equipe |
| B4 | B4 | done | Escovação supervisionada |
| B5 | B5 | done | Preventivos |
| B6 | B6 | done | TRA |
| M1 | M1 | done | Média atendimentos eMulti |
| M2 | M2 | done | Ações interprofissionais |

## Equipes eAP

Regras com `team_kind: esf` aplicam-se também a equipes `eap` via [`RuleCatalog`](../../lib/indicators/rule_catalog.rb) (APS primária).

## Auditoria automatizada

```bash
bin/rails indicators:audit_coverage
```

Compara definições Ruby (`methodology_pack_definitions.rb`), export JSON, regras em banco e predicados registrados em `ClinicalEvidence` / `CitizenScope`.
