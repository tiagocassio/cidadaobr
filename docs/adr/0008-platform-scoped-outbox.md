# ADR 0008: Platform-scoped outbox (global events)

## Status

Accepted — jun/2026 (EPIC-12 S9).

## Context

Dados de referência MS/LEDI (`reference_*`) são **globais** (sem `municipality_id`). `RecordPlatformEvent` exige `TenantContext` e grava `domain_events` / `outbox_messages` municipais.

EPIC-12 S9 exige publicar `reference.release.published` (Kafka topic `reference-release-published`) após nova `reference_data_releases`, com a mesma garantia transacional do ADR-0006.

## Decision

### Tabelas

| Tabela | Escopo |
|--------|--------|
| `platform_events` | Append-only; sem colunas tenant |
| `platform_outbox_messages` | Fila Kafka; `platform_event_id` único |

Sem RLS — dados de plataforma.

### Commands

- `RecordGlobalPlatformEvent` — append evento + outbox na mesma transação (`write_transaction` sem tenant).
- Envelope Kafka via `Cidadaobr::EventEnvelope.from_platform_event` (`municipality_id` nil).

### Publisher

- `PlatformOutboxPublisher` — varredura global (sem loop por município).
- `PublishOutboxMessagesJob` chama `PlatformOutboxPublisher` antes de `OutboxPublisher`.

### Primeiro evento

`Reference::Commands::PublishRelease` emite `reference.release.published` somente quando o checksum é novo.

### Consumer

`ReferenceDataReleasePublishedConsumer` — idempotência sem `TenantContext` (envelope sem `municipality_id` obrigatório).

## Consequences

- Eventos municipais e globais permanecem separados.
- Novos eventos globais: adicionar constante em `Cidadaobr::KafkaTopics`, `bin/kafka_create_topics`, consumer ou ADR-0007 (`event_type` = topic).

## References

- [ADR-0006](0006-platform-write-contract.md)
- [ADR-0007](0007-kafka-topic-consumer-policy.md)
- [epic-00-remediation.md](../epic-00-remediation.md)
