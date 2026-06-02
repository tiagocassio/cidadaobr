# ADR 0002: Polyrepo for mobile apps and OpenAPI contract

## Status

Accepted (2026-05-28)

## Context

CidadãoBR Saúde ships three client surfaces: municipal web (Hotwire in `cidadaobr`), citizen mobile (Flutter), and field mobile (Flutter, later). Coupling Flutter code inside the Rails repository complicates CI, release cadence, and store submission.

## Decision

- **Polyrepo (Option A):** keep `cidadaobr` as API + web only.
- Sibling repositories (**entrega Fase 8**, após web/API Fases 0–7):
  - `cidadaobr-mobile-shared` — Dart packages (`api_client` from OpenAPI, shared tokens later).
  - `cidadaobr-citizen` — Flutter citizen app (EPIC-04 app + EPIC-10 UI).
  - `cidadaobr-field` — Flutter field app (EPIC-08 + EPIC-09 Field UI).
- **Contract SSOT:** `doc/api/openapi.v1.yaml` in `cidadaobr`, versioned with git tags `openapi-x.y.z`.
- **Web gestão (Hotwire)** reception actions such as `POST /web/appointments/:id/no_show` are intentionally **not** in OpenAPI v1; v1 targets citizen/field JSON under `/api/v1/`.
- Mobile pins OpenAPI version when generating the HTTP client.
- Breaking API changes require `/api/v2/` and a changelog entry; mobile updates client generation before release.

## Kafka topics (gestão / indicadores)

- `event_type` and Kafka topic are the same hyphen-separated string (`Cidadaobr::KafkaTopics`).
- Provision topics via `bin/kafka_create_topics` before deploying consumers (`IndicatorRecalculationConsumer`, etc.).
- Recalculation on that topic runs `RuleCatalog.appointment_dependent_codes` only (e.g. C1), not linkage indicators that use encounters/clinical predicates alone.

## Consequences

- Rails PRs that change citizen/field JSON must update OpenAPI in the same PR (or follow-up before tag).
- Local dev expects clones under a common parent directory (see master plan).
- CI in each repo is independent; contract tests can run against a tagged OpenAPI artifact.

## References

- [docs/padrão_ledi_e-sus_4f004208.plan.md](../padrão_ledi_e-sus_4f004208.plan.md) — Repositórios Git, roteiro S1–S7
- [doc/api/openapi.v1.yaml](../../doc/api/openapi.v1.yaml)
