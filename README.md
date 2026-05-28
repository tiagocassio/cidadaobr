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

Para migrar manualmente:

```bash
POSTGRES_APP_USER=postgres POSTGRES_APP_PASSWORD=postgres bin/rails db:prepare
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

## Serviços

```bash
docker compose up -d   # Postgres + Kafka (Karafka)
bin/dev                # Rails + assets
```

## Produção

Configure o runtime com `POSTGRES_APP_USER=cidadaobr_app` e `CIDADAOBR_DATABASE_PASSWORD` (ou `POSTGRES_APP_PASSWORD`). O deploy deve garantir que `db:prepare` ou `db:schema:load` seja seguido de bootstrap admin (já encadeado nas tasks `db:prepare` e `db:schema:load`).
