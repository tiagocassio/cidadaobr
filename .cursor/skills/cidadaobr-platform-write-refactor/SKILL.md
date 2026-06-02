---
name: cidadaobr-platform-write-refactor
description: >
  Refactors and organizes cidadaobr domain writes to match ADR-0006
  (hybrid AR + platform events + CommandBus). Use when adding or changing
  mutations, lib/**/commands, controllers that save models, campaigns/routing/
  inventory, RecordPlatformEvent, OutboxPublisher, tenant RLS, or when the user
  mentions ADR-0006, volta aos trilhos, remediação, or platform write contract.
---

# cidadaobr — platform write refactor skill

Reimpor o **contrato de escrita** da Fase 0 sem Event Sourcing puro. Fonte da verdade = tabelas operacionais; eventos = integração e auditoria.

## Before coding

1. Read [ADR-0006](../../../docs/adr/0006-platform-write-contract.md) and the wave you are in ([epic-00-remediation.md](../../../docs/epic-00-remediation.md)).
2. Run audit (optional): `.cursor/skills/cidadaobr-platform-write-refactor/scripts/audit-violations.sh`
3. Open [examples.md](examples.md) for gold vs anti-patterns.

## Write contract (mandatory)

| Step | Rule |
|------|------|
| Location | `lib/<context>/commands/<verb>_<noun>.rb` (scheduling, ledi, campaigns, routing, inventory, indicators, territory/citizens) |
| Base | Prefer `ApplicationCommand` + `CommandBus.dispatch(Class, **params)` from controllers/APIs |
| Transaction | `write_transaction` on `ApplicationCommand` (tenant RLS when `TenantContext` is set) |
| Tenant | Validate `municipality_id` / `health_facility_id` vs membership or JWT |
| Events | `RecordPlatformEvent.call` when crossing contexts, listed in `Cidadaobr::KafkaTopics::ALL`, or audit-worthy transition |
| Topic | Same string as `event_type` (`Cidadaobr::KafkaTopics::*`); `topic` kwarg optional |
| Controller | No `Model.create!` / `save!` / `update!` for domain mutations |

**Do not:** replay aggregates from `domain_events`; add `rails_event_store`; read `domain_events` in UI.

## When to emit `RecordPlatformEvent`

Emit (with outbox) if any:

- Another bounded context consumes the change (agenda → indicators; campaign → routes; stock → kits).
- Event type is (or will be) in `Cidadaobr::KafkaTopics::ALL` (and `bin/kafka_create_topics`).
- Business transition: publish routes, reserve supplies, cancel campaign, etc.

Optional for local admin CRUD with no consumer yet.

## Remediation waves (priority)

| Wave | Focus | Key files |
|------|--------|-----------|
| **B** | Campaigns + routes + supply | `lib/campaigns/commands/build_campaign_target_list.rb`, `lib/routing/`, `lib/inventory/`, `HomeVisitCampaignsController`, `Cidadaobr::KafkaTopics`, `bin/kafka_create_topics` |
| **C** | Web cadastro | `CitizensController`, `HouseholdsController` → territory/citizens commands |
| **D** | CQRS light | `ApplicationCommand`, `QueryBus` for heavy reads |

Suggested event types (Onda B) — add to `TOPIC_MAPPING` and Kafka topics together:

- `campaign.targets.built`
- `home_visit.route.generated`, `home_visit.route.published`
- `visit_route.supplies.reserved`, `visit_route.supplies.dispatched`

## Refactor workflow

1. **Identify** mutation in controller or fat model callback.
2. **Extract** command under correct `lib/<context>/commands/`.
3. **Move** AR writes + validations into command; keep return value explicit (`Result` or entity).
4. **Add** `RecordPlatformEvent` if checklist above says yes; extend `TOPIC_MAPPING` + topic creation script in same PR.
5. **Wire** controller: `CommandBus.dispatch(Command, **permitted)`.
6. **Test** request/command spec: `DomainEvent` + `OutboxMessage` when event required; tenant isolation unchanged.

Keep PRs small: one command or one controller per PR when possible.

## Folder map

| Context | Path |
|---------|------|
| scheduling | `lib/scheduling/commands/` |
| ledi | `lib/ledi/commands/` |
| territory | `lib/territory/commands/` (cadastro FCD, UBS, equipes, microáreas) |
| platform | `lib/platform/commands/` (usuários municipais) |
| campaigns | `lib/campaigns/commands/` |
| routing | `lib/routing/commands/` |
| inventory | `lib/inventory/commands/` |
| indicators | `lib/indicators/commands/` |
| reads | `app/queries/` + `QueryBus.ask` (complex only) |
| infra commands | `app/commands/` |

Gold references: `Scheduling::BookAppointment`, `Ledi::ValidateClinicalRecord`, `Indicators::DetectCitizenGaps`.

## Tests

- Command/request spec: count `DomainEvent` by `event_type`; `OutboxMessage` with matching topic.
- Do not break existing RLS/request specs; use same tenant fixtures as neighbors.
- After new topics: run `bin/kafka_create_topics` (or document in PR if CI mocks Kafka).

## PR checklist (paste in description)

- [ ] Mutation only via command + `CommandBus.dispatch` (or documented exception)
- [ ] Tenant + `write_transaction` in command
- [ ] `RecordPlatformEvent` if cross-context / mapped / transition
- [ ] `TOPIC_MAPPING` + Kafka topic if new event type
- [ ] Specs for event+outbox when applicable
- [ ] ADR-0006 / platform-write-remediation wave noted (B/C/D)

## Additional resources

- [reference.md](reference.md) — audit `rg` patterns, envelopes, consumers
- [examples.md](examples.md) — code templates
- [scripts/audit-violations.sh](scripts/audit-violations.sh) — quick drift scan
