## Summary

<!-- What changed and why (1–3 sentences). -->

## Checklist

- [ ] Domain mutations live in `lib/<context>/commands/` (see [ADR-0006](docs/adr/0006-platform-write-contract.md))
- [ ] Web/API controllers use `CommandBus.dispatch` — run `bin/ci_controller_writes`
- [ ] Integration events use `RecordPlatformEvent` / `RecordGlobalPlatformEvent` with `Cidadaobr::KafkaTopics` (`event_type` = Kafka topic)
- [ ] New Kafka topics: constant in `lib/cidadaobr/kafka_topics.rb` + `bin/kafka_create_topics`
- [ ] Specs use `with_tenant` for tenant-scoped behavior
- [ ] `bundle exec rspec` (or affected paths) passes
- [ ] Citizen/field JSON changes: update `doc/api/openapi.v1.yaml` and `spec/requests/api/v1/citizen/openapi_contract_spec.rb` when applicable

## Test plan

<!-- Commands run or manual steps. -->
