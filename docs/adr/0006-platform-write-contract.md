# ADR 0006: Platform write contract (EPIC-00)

## Status

Accepted — **reafirma EPIC-00** após deriva CRUD em campanhas/rotas/cadastro web (jun/2026).

## Context

EPIC-00 entregou `domain_events`, outbox transacional, Karafka, `CommandBus`/`QueryBus`, RLS e auth. Fases 2–5 adicionaram features com **ActiveRecord direto** em controllers e commands sem eventos.

O plano mestre descreve Event Sourcing “puro” para agregados críticos; o código adotou **modelo híbrido**: tabelas operacionais como fonte da verdade + eventos para integração e auditoria.

Sem contrato explícito, cada feature nova aumenta a deriva.

## Decision

### 1. Modelo de persistência (oficial)

| Camada | Papel |
|--------|--------|
| **Tabelas operacionais** | Fonte da verdade do estado atual (MVP e médio prazo). |
| **`domain_events`** | Log append-only de decisões; **não** replay obrigatório para reconstruir agregados. |
| **Outbox + Kafka** | Integração entre contextos, projeções assíncronas, indicadores, LEDI. |
| **Projectors** | Materializam read models a partir de eventos ou fichas (ex.: LEDI → `citizens`). |

Não adotar `rails_event_store` neste ciclo. Não exigir reconstrução de agregado a partir de eventos.

### 2. Contrato de escrita (obrigatório daqui em diante)

Toda **mutação de domínio** (create/update/delete de entidades operacionais, transições de status, reservas, publicação de rotas) deve:

1. Executar em **`lib/<context>/commands/`** (ou `app/commands/` para infra), herdando **`ApplicationCommand`** quando possível.
2. Rodar dentro de **`write_transaction`** (`ApplicationCommand` → `TenantRls.write_transaction` quando há `TenantContext`; senão `ActiveRecord::Base.transaction`).
3. Validar escopo tenant (`municipality_id` / `health_facility_id` vs membership ou JWT).
4. Ser invocada pelos controllers/APIs via **`CommandBus.dispatch(CommandClass, **params)`** — não `Model.create!` em controller.

**Evento de plataforma** (`RecordPlatformEvent`) é obrigatório quando a operação:

- altera dados consumidos por **outro bounded context** (ex.: agenda → indicadores; campanha → rotas; estoque → provisionamento); ou
- está listada no catálogo de eventos de integração ([`OutboxPublisher::TOPIC_MAPPING`](../../app/services/outbox_publisher.rb)); ou
- representa transição de negócio auditável (publicar rotas, reservar kit, cancelar campanha).

Evento **opcional** para CRUD administrativo local (ex.: editar nome de sala) até haver consumidor.

### 3. Contrato de leitura (CQRS pragmático)

- Leituras simples: ActiveRecord em controller com scopes tenant — **aceito**.
- Leituras complexas (dashboards, listagens com regras): preferir **`app/queries/`** + `QueryBus.ask`.
- Não ler de `domain_events` em telas de usuário.

### 4. Estrutura de pastas

Equivalente ao plano `app/domains/<context>`:

| Contexto | Pasta |
|----------|--------|
| scheduling | `lib/scheduling/` |
| ledi | `lib/ledi/` |
| inventory | `lib/inventory/` |
| routing | `lib/routing/` |
| campaigns | `lib/campaigns/` |
| indicators | `lib/indicators/` |

### 5. Kafka / envelope

- Payload publicado = **`Cidadaobr::EventEnvelope`** (tenant keys obrigatórias).
- Consumers: idempotência via `kafka_processed_events`; tenant scope antes de projetar.

## Consequences

- **Positivo:** alinha time ao que já funciona (agenda, LEDI); evita ES prematuro.
- **Trabalho:** refatorar controllers e commands de Fase 5+ para o contrato; ampliar `TOPIC_MAPPING` para campanhas/rotas.
- **Testes:** request specs devem provar que mutações críticas criam `DomainEvent` + `OutboxMessage` quando aplicável.

## Compliance checklist (platform write gate)

Ver [epic-00-remediation.md](../epic-00-remediation.md).

## References

- [ADR-0001](0001-tenant-isolation-rls.md) — RLS
- [ADR-0002](0002-multi-repo-mobile-and-api-contracts.md) — APIs e tópicos
- Plano mestre § [Arquitetura: Event Sourcing + CQRS + EDA](../padrão_ledi_e-sus_4f004208.plan.md#arquitetura-event-sourcing--cqrs--eda)
