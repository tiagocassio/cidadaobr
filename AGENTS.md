# Agent guide — cidadaobr

## Platform writes (read first for mutations)

Fase 0 defines **hybrid** persistence (ADR-0006): ActiveRecord = source of truth; `domain_events` + outbox/Kafka for integration — not full Event Sourcing replay.

| Resource | Location |
|----------|----------|
| **Skill (refactor)** | `.cursor/skills/cidadaobr-platform-write-refactor/SKILL.md` |
| ADR write contract | `docs/adr/0006-platform-write-contract.md` |
| Platform outbox (global) | `docs/adr/0008-platform-scoped-outbox.md` |
| Remediation waves | `docs/epic-00-remediation.md` |
| Phase/epic roadmap | `docs/roteiro-organizado-fases-epicos.md` |

Invoke skill when changing commands, controllers that save models, campaigns/routing/inventory, or Kafka/outbox.

Audit: `.cursor/skills/cidadaobr-platform-write-refactor/scripts/audit-violations.sh`

**Kafka topics:** hyphen-only names in `lib/cidadaobr/kafka_topics.rb` (`event_type` in DB may use dots).

**CI gate:** `bin/ci_controller_writes` (job `controller_writes_gate` — bloqueia `create!/update!/save!/destroy!` em `app/controllers`).

**Conformidade (jun/2026):** Ondas B–J + homogeneidade I concluídas; próximo: EPIC-12 release + piloto Fase 5 — `docs/epic-00-remediation.md`.

## Stack

Rails 8, PostgreSQL (RLS), Karafka, multi-tenant municipalities. Mobile apps are **Fase 8** (Flutter), not part of Fase 3 API work.

## Conventions

English code identifiers; Portuguese UI copy via I18n (`config/locales/`).

## Planning IDs (EPIC / STORY / TASK) — code vs docs

**Do not** embed backlog identifiers (`EPIC-*`, `STORY-*`, `TASK-*`, including variants like `EPIC-05b`) in **executable code or config consumed by the app**:

- Ruby (`.rb`), Stimulus/JS, ERB, Rake tasks, `bin/*`, CI workflows
- `config/locales/*.yml`, `vendor/**` fixtures, `doc/api/openapi*.yaml`
- Comments, `desc` strings, OpenAPI summaries, user-facing I18n messages, shell echoes

Use **descriptive names** instead (e.g. “reference data gate”, “scheduling flows”, “citizen immunization wallet API”).

**Allowed** in documentation and planning artifacts only:

- `docs/**/*.md`, root `README.md`, `AGENTS.md`, `.cursor/plans/*.md`, `.github/ISSUES/*.md`
- `docs/backlog/*.csv` (IDs are the data model of the export)

Roadmap detail lives in [docs/roteiro-organizado-fases-epicos.md](docs/roteiro-organizado-fases-epicos.md) — link from code comments to that doc if context is needed; do not paste task IDs into source.

**Verify after edits** (should return no matches outside `docs/` and `*.md`):

```bash
rg 'EPIC-[0-9]|TASK-[0-9]|STORY-[0-9]' app lib spec config bin vendor doc/api .github \
  --glob '*.rb' --glob '*.yml' --glob '*.yaml' --glob '*.rake' --glob '*.sh' --glob '*.js' --glob '*.erb'
```
