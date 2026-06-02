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

Senhas: `POSTGRES_SCHEMA_PASSWORD` (admin), `POSTGRES_APP_PASSWORD` (conexão do app em runtime) e `CIDADAOBR_APP_ROLE_PASSWORD` (senha do papel PostgreSQL `cidadaobr_app`, default `cidadaobr_app`).

Credenciais do **Docker Compose** (`docker-compose.yml`): usuário `postgres`, senha `postgres`, banco `cidadaobr_development`, porta `5432`.

> Superusuários (`postgres`) **sempre ignoram RLS**. Nunca use `postgres` como usuário da aplicação em produção.

## Setup local

Fluxo recomendado (cria o banco, migra, bootstrap RLS, papel `cidadaobr_app` e seed):

```bash
docker compose up -d postgres
bin/setup --skip-server
```

O `bin/setup` roda `db:prepare` como `postgres` (via variáveis de ambiente no script), executa `Cidadaobr::DatabaseBootstrap` (PostGIS, políticas RLS, grants) e `Cidadaobr::DatabaseRoleSetup` (papel `cidadaobr_app`).

Depois do setup, o runtime usa `cidadaobr_app` / `cidadaobr_app` — padrão em [`config/database.yml`](config/database.yml).

### Bootstrap manual (sem `bin/setup`)

Útil na primeira vez ou com volume Postgres novo, quando `bin/rails db:migrate` falha com `password authentication failed for user "cidadaobr_app"`:

```bash
docker compose up -d postgres

POSTGRES_APP_USER=postgres POSTGRES_APP_PASSWORD=postgres \
POSTGRES_SCHEMA_USER=postgres POSTGRES_SCHEMA_PASSWORD=postgres \
CIDADAOBR_APP_ROLE_PASSWORD=cidadaobr_app \
bin/rails db:prepare

bin/rails db:seed
```

Não rode apenas `bin/rails db:migrate` ou `db:seed` antes do bootstrap: o papel `cidadaobr_app` ainda não existe no cluster.

### Migrations no dia a dia

Tasks `db:migrate`, `db:rollback` e `db:prepare` alternam para `POSTGRES_SCHEMA_USER` (`postgres` no Docker) e restauram a conexão do app ao final:

```bash
bin/rails db:migrate
# ou
bin/rails db:prepare
```

### Solução de problemas

| Sintoma | Causa provável | Ação |
|---------|----------------|------|
| `password authentication failed for user "cidadaobr_app"` | Papel inexistente ou senha do papel ≠ `cidadaobr_app` (ex.: bootstrap sem `CIDADAOBR_APP_ROLE_PASSWORD`) | `bin/setup --skip-server` ou bloco **Bootstrap manual** acima |
| `connection refused` na porta 5432 | Postgres parado | `docker compose up -d postgres` |
| `db:seed` com `duplicate key` em slots | Seed reexecutado | Normal após correção idempotente; rode `db:seed` de novo |

Para redefinir dados locais: `bin/setup --skip-server --reset` (apaga e recria o banco de desenvolvimento).

Status do produto e piloto web: [`docs/commercial/status-plano-2026-06.md`](docs/commercial/status-plano-2026-06.md).

## Testes

```bash
docker compose up -d postgres
bin/rails db:test:prepare
bundle exec rspec
```

Os testes carregam o schema como `postgres`, aplicam RLS/grants uma vez no `before(:suite)` e executam exemplos conectados como `cidadaobr_app`.

## Seeds (dev)

Requer setup concluído (`bin/setup` ou `db:prepare` com bootstrap). O `bin/setup` já executa o seed; para repetir:

```bash
bin/rails db:seed
```

Logins demo:

- `admin@cidadaobr.local` / `password123` (escopo município)
- `ubs.centro@cidadaobr.local` / `password123` (escopo UBS Centro)

Checklist de validação manual: [`docs/commercial/piloto-validacao-tecnica.md`](docs/commercial/piloto-validacao-tecnica.md).

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

Fluxo Fase 1: importar transporte → validar ficha → submeter lote (`ledi-batch-submitted` no Kafka). Envio HTTP ao PEC fica para EPIC-09.

Variável opcional `LEDI_PEC_STUB_REJECT=true` faz o consumer `LediBatchReadyConsumer` simular rejeição automática do PEC em desenvolvimento (não usar em produção).

Eventos novos (constantes em `Cidadaobr::KafkaTopics`, mesmo nome no tópico Kafka) entram na outbox via `RecordPlatformEvent`. Publique com `bin/rails outbox:publish` (ou agende o task) até existirem consumidores de negócio dedicados (EPIC-09 / EPIC-03). Karafka já registra rotas placeholder em `PlatformEventConsumer`.

## Platform write (desenvolvimento)

Mutações de domínio seguem [ADR-0006](docs/adr/0006-platform-write-contract.md):

- Commands em `lib/<context>/commands/`, expostos via `CommandBus.dispatch`
- `write_transaction` em `ApplicationCommand` (RLS quando há `TenantContext`)
- Eventos de integração: `RecordPlatformEvent` com `event_type` = tópico Kafka (`Cidadaobr::KafkaTopics`)

Gate local: `bin/ci_controller_writes`. Matriz de conformidade: [docs/epic-00-remediation.md](docs/epic-00-remediation.md). Skill Cursor: `.cursor/skills/cidadaobr-platform-write-refactor/`.

### Recriar banco do zero (desenvolvimento)

`db/schema.rb` é gerado pelas migrations — não editar à mão. Para reset completo:

```bash
# development
docker compose exec -T postgres psql -U postgres -c "DROP DATABASE IF EXISTS cidadaobr_development;"
docker compose exec -T postgres psql -U postgres -c "CREATE DATABASE cidadaobr_development OWNER postgres;"
POSTGRES_SCHEMA_USER=postgres POSTGRES_SCHEMA_PASSWORD=postgres bin/rails db:migrate
bin/rails db:seed

# test (antes de rspec)
docker compose exec -T postgres psql -U postgres -c "DROP DATABASE IF EXISTS cidadaobr_test;"
docker compose exec -T postgres psql -U postgres -c "CREATE DATABASE cidadaobr_test OWNER postgres;"
RAILS_ENV=test POSTGRES_SCHEMA_USER=postgres POSTGRES_SCHEMA_PASSWORD=postgres bin/rails db:migrate
```

## Serviços

```bash
docker compose up -d   # Postgres + Kafka (Karafka)
bin/dev                # Rails + assets
```

## Produção

Configure o runtime com `POSTGRES_APP_USER=cidadaobr_app` e `CIDADAOBR_DATABASE_PASSWORD` (ou `POSTGRES_APP_PASSWORD`). O deploy deve garantir que `db:prepare` ou `db:schema:load` seja seguido de bootstrap admin (já encadeado nas tasks `db:prepare` e `db:schema:load`).
