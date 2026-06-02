# ADR 0007: Kafka topic consumer policy (publish-only vs wired)

## Status

Accepted — jun/2026 (Onda J, EPIC-00 remediação).

## Context

Campanhas domiciliares, cadastro territorial e vacina passaram a **publicar** eventos via outbox (`RecordPlatformEvent` + `TOPIC_MAPPING`). Nem todo tópico precisa de consumer síncrono no monólito no MVP: projeções pesadas e apps campo ficam para **Fase 8**.

Sem política explícita, cada PR novo poderia adicionar consumers placeholder sem regra.

**Naming:** `event_type` and Kafka topic are the **same** hyphen-separated string (`Cidadaobr::KafkaTopics`). `EVENT_TO_TOPIC` is identity (allowlist only).

## Decision

### Tópicos com consumer de negócio (hoje)

| Kafka topic | Consumer | Efeito |
|-------------|----------|--------|
| `clinical-record-persisted` | `ClinicalRecordPersistedConsumer` | Projeção LEDI → operacional |
| `ledi-batch-submitted` | `LediBatchReadyConsumer` | Pipeline batch |
| `appointment-*` (6) | `IndicatorRecalculationConsumer` | Indicadores |
| `citizen-registered` | `CitizenRegisteredConsumer` | Log/idempotência (MVP) |
| `reference-release-published` | `ReferenceDataReleasePublishedConsumer` | Log/idempotência; cache bust futuro |
| `domain-outbox` | `DomainOutboxConsumer` | Infra outbox |

### Tópicos publish-only (sem consumer até novo ADR / Fase 8)

Publicados em `bin/kafka_create_topics` e `OutboxPublisher::TOPIC_MAPPING`, **sem** rota em `karafka.rb`:

| Topic (=`event_type`) | Motivo |
|------------------------|--------|
| `campaign-targets-built` | Integração futura / analytics |
| `home-visit-route-generated` | App campo Fase 8 |
| `home-visit-route-published` | idem |
| `visit-route-supplies-reserved` | idem |
| `visit-route-supplies-dispatched` | idem |
| `citizen-updated` | Projeções opcionais |
| `care-team-created` / `care-team-updated` | Sync externo futuro |
| `vaccination-campaign-*` | Gestão web já consistente via AR |
| `immunobiological-lot-received` | Estoque local |

### Placeholder

`PlatformEventConsumer` permanece apenas para tópicos explicitamente roteados (ex.: `ledi-batch-statuschanged`, `indicator-gap-detected`) — **não** substitui handler de domínio.

## Consequences

- **Positivo:** menos consumo Kafka e menos acoplamento prematuro no monólito.
- **Negativo:** integrações externas devem assinar tópicos diretamente ou aguardar Fase 8.
- **PR checklist:** novo `event_type` → `KafkaTopics` + `bin/kafka_create_topics`; consumer só com ADR ou linha nesta tabela.

## References

- [ADR-0006](0006-platform-write-contract.md)
- [epic-00-remediation.md](../epic-00-remediation.md) — Onda J
- `lib/cidadaobr/kafka_topics.rb`
