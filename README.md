# CidadãoBR Saúde

Plataforma municipal de saúde com multi-tenant, event sourcing e Row Level Security (RLS) no PostgreSQL.

## Requisitos

- Ruby 3.4+
- PostgreSQL 18+ com PostGIS (via Docker Compose)
- Node/Yarn (Hotwire + daisyUI plugin)

## Frontend (CSS)

- **Tailwind CSS** via [`tailwindcss-rails`](https://github.com/rails/tailwindcss-rails) (entrada: `app/assets/tailwind/application.css`, saída: `app/assets/builds/tailwind.css`)
- **daisyUI** como plugin Tailwind (tema padrão: `corporate`)
- Build manual: `bin/rails tailwindcss:build`
- Dev: `bin/dev` (Foreman com `tailwindcss:watch` + esbuild JS)

## Banco de dados: dois papéis

A aplicação usa **dois usuários PostgreSQL**:

| Papel | Variável | Default | Uso |
|-------|----------|---------|-----|
| Admin (schema) | `POSTGRES_SCHEMA_USER` | `postgres` | migrations, `db:prepare`, extensões PostGIS, grants, políticas RLS |
| App (runtime) | `POSTGRES_APP_USER` | `cidadaobr_app` | servidor Rails, jobs, testes (sem bypass de RLS) |

Senhas: `POSTGRES_SCHEMA_PASSWORD` (admin) e `POSTGRES_APP_PASSWORD` (app).

> Superusuários (`postgres`) **sempre ignoram RLS**. Nunca use `postgres` como usuário da aplicação.

## Setup local

```bash
docker compose up -d postgres
bin/setup --skip-server
```

O `bin/setup` roda `db:prepare` como `postgres` e reaplica grants/policies RLS via `Cidadaobr::DatabaseBootstrap`.

Para migrar manualmente (usa `POSTGRES_SCHEMA_USER` automaticamente nas tasks `db:migrate`, `db:rollback`, etc.):

```bash
bin/rails db:migrate
bin/rails db:prepare
```

## Testes

```bash
docker compose up -d postgres
bin/rails db:test:prepare
bundle exec rspec
```

Os testes carregam o schema como `postgres`, aplicam RLS/grants uma vez no `before(:suite)` e executam exemplos conectados como `cidadaobr_app`.

## Seeds (dev)

```bash
bin/rails db:seed
```

- `admin@cidadaobr.local` / `password123` (escopo município)
- `ubs.centro@cidadaobr.local` / `password123` (escopo UBS)

## LEDI (e-SUS APS 7.4.0)

Integração com o padrão **LEDI APS 7.4.0** (compatível PEC ≥ 5.4.34):

- Artefatos vendor em `vendor/ledi/7.4.0/` (Thrift + XSD de referência)
- Configuração em `config/ledi.yml` (versão, `tp_cds_origem`, mapa de tipos serializados)
- Domínio em `lib/ledi/` (deserialização, validação, importação, lotes, projeções)

Comandos úteis:

```bash
bin/rails db:seed                              # inclui catálogo MVP e instalação dev
bin/rails ledi:catalog:seed                    # recarrega regras/campos LEDI
bin/rails ledi:catalog:import_xsd              # stub para importação futura via XSD
```

Fluxo Fase 1: importar transporte → validar ficha → submeter lote (`ledi.batch.ready` no Kafka). Envio HTTP ao PEC fica para EPIC-09.

Variável opcional `LEDI_PEC_STUB_REJECT=true` faz o consumer `LediBatchReadyConsumer` simular rejeição automática do PEC em desenvolvimento (não usar em produção).

Eventos novos (`ledi.batch.status_changed`, `appointment.*`) entram na outbox via `RecordPlatformEvent`. Publique com `bin/rails outbox:publish` (ou agende o task) até existirem consumidores de negócio dedicados (EPIC-09 / EPIC-03). Karafka já registra rotas placeholder em `PlatformEventConsumer`.

## Serviços

```bash
docker compose up -d   # Postgres + Kafka (Karafka)
bin/dev                # Rails + assets
```

## Produção

Configure o runtime com `POSTGRES_APP_USER=cidadaobr_app` e `CIDADAOBR_DATABASE_PASSWORD` (ou `POSTGRES_APP_PASSWORD`). O deploy deve garantir que `db:prepare` ou `db:schema:load` seja seguido de bootstrap admin (já encadeado nas tasks `db:prepare` e `db:schema:load`).
