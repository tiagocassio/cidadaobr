# ADR-0010: Integração HTTP com PEC municipal (envio LEDI)

## Status

Accepted — Fase 6 (EPIC-09)

## Context

Lotes LEDI (`LediBatch`) agregam `transport_records` validados e são submetidos ao PEC municipal após o evento `ledi.batch.ready`. O MVP usava `Ledi::PecSubmissionService` always-accept (stub), adequado apenas para desenvolvimento.

Produção exige envio HTTP configurável por município, idempotência por `batch_number`, e persistência de accepted/rejected com motivo.

## Decision

1. **Config por município:** colunas `pec_base_url` e `pec_api_token` em `municipalities`; `pec_api_token` cifrado via **Active Record Encryption** (`encrypts` no model). Ambientes deployados (produção/staging) exigem `ACTIVE_RECORD_ENCRYPTION_*` (sem fallback). Dev/test usam defaults locais. Em deploy, **URL e token vêm só do município**; `ENV["PEC_BASE_URL"]` / `ENV["PEC_API_TOKEN"]` servem apenas em dev/demo local. `deployed?` = qualquer `RAILS_ENV` que não seja `development`/`test` (inclui `staging`).

2. **Cliente HTTP:** `Ledi::PecClient` (Net::HTTP) — `POST {base}/api/v1/ledi/lotes/{batch_number}` (`URI.join` preserva path prefix do município) com corpo `application/octet-stream` (concatenação ordenada de `payload_binary` dos registros validados). Retry até 3× em 5xx/429/timeout de rede.

3. **Resposta JSON esperada:** `{ "status": "accepted" }` ou `{ "status": "rejected", "reason": "..." }`. HTTP 2xx com status accepted; demais casos → rejected com motivo.

4. **Fallback não-produção:** sem URL configurada, dev/test aceita lote **somente com** registros `validated`. **Produção** sem URL → rejeição com motivo explícito.

5. **Pós-envio:** accept → `LediBatch#submitted` + `transport_records` → `sent`; reject → `RejectLediBatch` + registros → `rejected`.

6. **Stub dev:** `LEDI_PEC_STUB_REJECT=true` rejeita lotes **sem** registros validados (simula falha XSD antes do envio). Não simula rejeição de payload válido.

7. **Versão LEDI / VersaoThrift:** o client **não** re-serializa fichas; `payload_binary` já deve conter `DadoTransporte` com `transport_version` de `config/ledi.yml` desde import/validação.

8. **Idempotência:** chave = `batch_number` na URL (PEC municipal). **App:** `pg_try_advisory_lock` serializa POST HTTP por lote (falha rápida → retry do consumer); `SubmitPecBatch` usa `with_lock` no lote; retorna cedo se já `submitted`; persiste `pec_accepted_at` **logo após** HTTP accept (ainda no fluxo advisory, antes de `submitted`); retry completa sem re-POST; estado misto `validated`+`sent` sem flag → reject (remediação manual abaixo); accept marca `validated` e `sent` como `sent`. Com `pec_accepted_at` setado, `finalize_pec_http!` completa e **não** rejeita por resposta HTTP posterior — evita falso reject em crash-retry quando PEC já aceitou o lote.

9. **Transação vs row lock (`mark_batch_submitted!`):** transição para `submitted`, update de `transport_records` e `RecordPlatformEvent` ficam no **mesmo** `write_transaction` ([ADR-0006](0006-platform-write-contract.md)). O `with_lock` na row do lote pode segurar lock durante insert outbox — trade-off aceito para atomicidade AR + evento.

## Operação / remediação

- **Tokens legados plain text:** antes de desligar `support_unencrypted_data` em deploy, executar `bin/rails pec:encrypt_tokens`.
- **Lote `rejected` por estado misto de transporte:** inspecionar `transport_records` do lote; alinhar status manualmente ou revalidar fichas; criar novo lote via fluxo LEDI normal — não reutilizar lote rejeitado.
- **Chaves encryption:** definir `ACTIVE_RECORD_ENCRYPTION_*` em todo ambiente que não seja `development`/`test` (inclui staging se `RAILS_ENV=production`).
- **`PecSubmissionInProgressError`:** outro worker segura `pg_try_advisory_lock` — consumer loga e re-lança; Karafka retenta sem marcar idempotência (`KafkaProcessedEvent` não gravado).
- **PEC accept + lote já `rejected`:** se `RejectLediBatch` venceu durante HTTP, `finalize_pec_http!` retorna sem raise; PEC pode ter o lote — remediação manual com município (cancelar/ignorar duplicata).
- **`InvalidBatchStateError` (accept sem `pec_accepted_at`):** estado inconsistente pós-HTTP — inspecionar lote; corrigir flag manualmente ou reprocessar após fix; não expectativa de auto-cura em retry.

## Consequences

- Integradores municipais devem expor endpoint compatível ou adapter sidecar até API oficial homogênea MS.
- Versão LEDI do transporte (`VersaoThrift` 7/4/1) deve estar presente nos payloads enviados; fixtures e importadores devem alinhar com `config/ledi.yml#transport_version`.
- Testes usam `WEBrick`/`Rack::Handler` ou stub de Net::HTTP — sem dependência Faraday.

## References

- `lib/ledi/pec_client.rb`
- `lib/ledi/pec_submission_service.rb`
- `lib/ledi/commands/submit_pec_batch.rb`
- [ADR-0006](0006-platform-write-contract.md) — writes via CommandBus
