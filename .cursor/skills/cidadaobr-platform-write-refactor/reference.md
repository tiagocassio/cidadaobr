# Platform write — reference (audit & integration)

## Docs (SSOT)

| Doc | Path |
|-----|------|
| Write contract | `docs/adr/0006-platform-write-contract.md` |
| Kafka consumers | `docs/adr/0007-kafka-topic-consumer-policy.md` |
| Remediation waves | `docs/epic-00-remediation.md` |
| Roteiro fases | `docs/roteiro-organizado-fases-epicos.md` |
| Kafka topic SSOT | `lib/cidadaobr/kafka_topics.rb` (`event_type` = topic) |

## Audit script

```bash
.cursor/skills/cidadaobr-platform-write-refactor/scripts/audit-violations.sh
```

Uses `rg` when installed; otherwise falls back to `grep` (no exit on missing ripgrep).
Optional: `sudo apt install ripgrep` (Debian/Ubuntu).

## Manual `rg` checks

```bash
# Controllers mutating AR directly (review each hit)
rg '\.(create|update|save|destroy)!\(' app/controllers --glob '*.rb'

# Commands without platform event (review; not all need events)
rg 'class \w+.*Command' lib -g '**/commands/*.rb' -l | while read f; do
  rg -q 'RecordPlatformEvent' "$f" || echo "no event: $f"
done

# Direct .call from controllers (prefer CommandBus)
rg '\w+::\w+\.call\(' app/controllers --glob '*.rb'

# KafkaTopics constants vs bin/kafka_create_topics
rg 'Cidadaobr::KafkaTopics::' lib app -g '*.rb'
```

## `RecordPlatformEvent` shape

```ruby
RecordPlatformEvent.call(
  event_type: Cidadaobr::KafkaTopics::APPOINTMENT_BOOKED,
  aggregate_type: "Appointment",
  aggregate_id: appointment.id,
  payload: { ... },
  care_team_id: appointment.care_team_id
)
```

Envelope on Kafka: `Cidadaobr::EventEnvelope` (tenant keys required). Consumers use `kafka_processed_events` for idempotency.

## `ApplicationCommand` / buses

- Dispatch: `CommandBus.dispatch(Scheduling::BookAppointment, citizen_id: ..., ...)`
- Ask: `QueryBus.ask(SomeQuery, **params)` for heavy reads in `app/queries/`
- Base: `app/commands/application_command.rb` (or project equivalent — match existing commands)

## Onda B — files often touched

| Command (examples) | Controller |
|--------------------|------------|
| `Campaigns::BuildCampaignTargetList` | `HomeVisitCampaignsController` |
| `Routing::GenerateVisitRoutes`, `PublishVisitRoutes` | same |
| `Inventory::ReserveVisitRouteSupplies`, `DispatchTeamSupplyKit` | same |

After adding mapping entries, update Kafka topic creation (project script under `bin/`) in the same change set.

## Gate Fase 6

Do not start clinical Fase 6 until platform-write-remediation gate in doc is satisfied (Onda B minimum for campaign/route events + specs).
