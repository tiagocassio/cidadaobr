# ADR-0005: Cobertura integral das Notas Metodológicas LEDI

## Status

Accepted — extends [ADR-0003](0003-epic05-mvp-scope.md)

## Context

ADR-0003 scoped EPIC-05 to MVP proxies (single good practice per quality indicator, encounter-based linkage, 0–100 CVAT scale) to unblock product pilots. The master plan and SAPS Notas Metodológicas (NT 30/2025, fichas C1–C7, B1–B6, M1–M2) define dozens of good practices (BPs), MS 0–10 linkage scoring, contact vs attendance distinction, MICI/MICDT validation, and tier caps when cadastro exceeds team limits.

Pilot users need auditability: which BP is implemented, which LEDI field is missing, and scores aligned to MS methodology—not a single proxy rule per indicator.

## Decision

1. **Normative source of truth** moves from inline Ruby in `db/seeds/indicator_catalog.rb` to `MethodologyPackDefinitions` in Ruby, synced idempotently by `MethodologyPackLoader.sync!`. Files under `lib/indicators/methodology/3493-2024/packs/*.json` are an exported audit trail (refreshed on `catalog:seed` via `sync!(export_json: true)` and manually via `rake indicators:catalog:export_packs`), not loaded at runtime.

2. **Coverage matrix** (`docs/indicators/methodology-coverage-matrix.md`) tracks every BP with status (todo / partial / done), resolver, spec, and LEDI dependency. EPIC-05b in the master plan references this matrix.

3. **Team scoring** supports multiple rules per `indicator_code`:
   - `good_practices_pct` for C2–C7 (BPs cumpridas / aplicáveis).
   - `linkage_aggregate` with `score_scale: ms_0_10` and fixed MS weights (3.0 V_CAD + 7.0 V_ACOMP + SAT bonus).
   - One `TeamIndicatorResult` per indicator per quadrimester (no overwrite across BPs).

4. **Linkage (Onda 1)** implements MICI/MICDT, FCI update window, contact+attendance counts, V_LIM tier cap, and eAP via `RuleCatalog` (eAP inherits eSF packs).

5. **External data:** V_SAT delivered via `TeamSatisfactionSurveyScore` + `Indicators::Commands::ImportSatisfactionSurvey` (2026-05-31). SIAPS conciliation remains a later wave. CVAT SAT bonus follows MS weights when import data exists for the quadrimester.

6. **Financial repasse** in `Scoring` stays illustrative; methodology scores use MS scales where specified but do not claim official Portaria repasse tables.

7. **Temporal windows** in pack numerators use two keys: `within_months` (rolling window from `reference_date`) and `lookback_months` (SQL prefilter for DUM-anchored rules such as C3-A `first_prenatal_consult`). Resolvers accept legacy `within_months` as fallback for `lookback_months` only on that resolver; new packs should use `lookback_months` explicitly.

8. **Effective encounter date** for clinical evidence is `GREATEST(clinical_records.encounter_at, MAX(linked encounters.encounter_at))` in SQL filters and `[record.encounter_at, linked].compact.max` in Ruby date checks, so a stale record timestamp cannot hide a newer citizen-linked encounter. Implemented in `lib/indicators/dsl_v1/resolvers/clinical_evidence.rb` (`clinical_records_for`, `encounter_at_for`).

## Consequences

- Seeds become a thin loader; diffs to methodology are reviewed in `methodology_pack_definitions.rb` + exported JSON + matrix, not 400-line seed files.
- Specs and `rake indicators:audit_coverage` guard pack/DB/resolver alignment only; matrix `partial`/`todo` rows are progress tracking and do not fail the rake.
- ADR-0003 MVP proxies are superseded for linkage and quality indicators; B/M indicators retain single-rule packs with room for LEDI field refinement.
- TASK-05-08 is **Done**: matrix **53/53 `done`** (2026-06-03, onda 2a PNI); C2.E calendário técnico MS via [ADR-0009](0009-pni-calendar-reference.md) — see [matriz](../indicators/methodology-coverage-matrix.md).
- **`mici_complete?` (EPIC-05b):** no fallback to municipal `citizens` columns — tenants must have valid FCI `identificacaoUsuarioCidadao` before V_CAD_COM scores; re-import or backfill FCI on deploy.
- **`latest_fcd_payload` (web FCD):** when no valid imported FCD `ClinicalRecord` exists, `RegistrationValidators` uses `household#to_fcd_payload` from the citizen’s `household_members`. This affects `micdt_complete?` and `microarea_linked?` for web-registered domiciles only; it does not relax `mici_complete?`.

## References

- `docs/indicators/methodology-coverage-matrix.md`
- `lib/indicators/methodology_pack_definitions.rb`
- `lib/indicators/methodology_pack_loader.rb`
- NT 30/2025 — [eSF/eAP SAPS](https://www.gov.br/saude/pt-br/composicao/saps/publicacoes/fichas-tecnicas/equipe-de-atencao-primaria-e-saude-da-familia)
