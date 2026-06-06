# Validação técnica — ambiente demo (pós-seed)

Checklist manual (~30 min) após `bin/rails db:seed` em ambiente de desenvolvimento ou piloto.

## Pré-requisitos

```bash
docker compose up -d postgres
bin/setup --skip-server
bin/rails db:seed
bin/ci_reference_gate   # EPIC-12 — valida release MS/LEDI antes de walk-in clínico
```

Credenciais demo:

- `admin@cidadaobr.local` / `password123` (escopo município)
- `ubs.centro@cidadaobr.local` / `password123` (escopo UBS Centro)

Equipes criadas pelo seed:

| INE | Nome | team_kind |
|-----|------|-----------|
| 0000000001 | Equipe Centro 01 | esf |
| 0000000002 | Equipe Norte 01 | esf |
| 0000000003 | Equipe Saúde Bucal Centro | esb |
| 0000000004 | Equipe eMulti Norte | emulti |

## Checklist manual

| # | Ação | Resultado esperado |
|---|------|-------------------|
| 1 | Login como admin municipal | Painel de indicadores acessível |
| 2 | Listar equipes no admin | 4 equipes com tipos ESF×2, eSB×1, eMulti×1 |
| 3 | Importar lote LEDI com FAO/FAC (quando disponível) | Recálculo dispara scores B/M |
| 4 | Painel gestor — visão município | Indicadores ESF (C*, V*) visíveis |
| 5 | Painel — equipe eSB | Indicadores B1–B6 (exceto B3 como gap individual) |
| 6 | Painel — equipe eMulti | Indicadores M1–M2 |
| 7 | B3 (exodontias) | Score de **equipe**, não pendência por cidadão |
| 8 | Projeção de repasse | Valor visível com **disclaimer** (estimativa, não oficial) |

## Checklist manual — Fase 5 (campanhas e rotas)

Após subir o servidor (`bin/rails server` ou compose), com login `ubs.centro@cidadaobr.local` ou `admin@cidadaobr.local`:

| # | Rota / ação | Resultado esperado |
|---|-------------|-------------------|
| F5-1 | `/web/campaigns/home_visit_campaigns` → nova campanha → **Montar público-alvo** | Alvos listados |
| F5-2 | **Gerar rotas** → **Calcular/reservar provisionamento** → **Publicar rotas** | Status `scheduled`, rotas `published` |
| F5-3 | Show da campanha: bloco **Progresso das equipes** | Percentual e equipes visíveis |
| F5-4 | **Despachar kit** por equipe | Romaneio em `/web/stock/team_supply_dispatches` |
| F5-5 | **Mapa de rotas** (`route_map`) | Mapa com paradas |
| F5-6 | `/web/campaigns/vaccination_campaigns` → wizard 4 passos → aprovar provisionamento → publicar | Campanha vacina ativa |

**Gate técnico (jun/2026):** F5-2 e F5-6 cobertos por request specs HTTP; F5-3..F5-5 com specs de lib (`visit_route_progress`, reserve/dispatch). Confirmar F5-1..F5-6 na UI com `bin/dev` antes de piloto prefeitura.

## Checklist manual — Fase 6 (clínica web + Plus API)

Com `bin/dev` e credenciais demo:

| # | Rota / ação | Resultado esperado |
|---|-------------|-------------------|
| F6-1 | `/web/appointments/walk_in` | Formulário exibe release de referência ativo |
| F6-2 | Registrar walk-in | Cidadão entra na fila de recepção |
| F6-3 | Relatório walk-in diário | `/web/appointments/walk_in_report` lista atendimentos do dia |
| F6-4 | `/web/shared_care_cases` → novo FCC | Caso criado com CIAP/CID |
| F6-5 | Evolução FCC | POST evolução persiste no caso |
| F6-6 | API Plus (curl/Postman) | `POST /api/v1/citizen/panic_alerts`, tele, meds — OpenAPI contract spec verde |
| F6-7 | Lote LEDI → PEC | Com `pec_base_url` configurado, lote `ready` → `submitted` ou `rejected` com motivo |

**Nota:** UI de pânico para gestor **não** faz parte da Fase 6 — consumo via app Citizen (Fase 8) + Kafka.

Specs automatizados (gate F6): `spec/lib/ledi/pec_*`, `spec/lib/indicators/fao_team_score_integration_spec.rb`, `spec/requests/web/shared_care_cases_spec.rb`, `spec/requests/api/v1/citizen/openapi_contract_spec.rb`.

Specs automatizados (gate): `bundle exec rspec` — suite verde (jun/2026). Campanhas: `spec/requests/web/stock_and_campaigns_spec.rb` (19 examples, fluxo domiciliar + wizard vacina via HTTP).

Banco local: recriar do zero com `docker compose exec -T postgres psql -U postgres -c 'DROP DATABASE ...'` + `bin/rails db:migrate`.

## Validação automatizada

```bash
bundle exec rspec spec/lib/indicators/
```

Cobertura principal: filtro `RuleCatalog` por `team_kind`, recálculo FAO/FAC, B3 como ratio de equipe, M1/M2 via FAC.

## Recálculo manual (console)

Com tenant municipal e equipe tipada:

```ruby
m = Municipality.find_by!(ibge_code: "3550308")
tenant = Cidadaobr::TenantScope.new(
  municipality_id: m.id, scope: "municipality",
  health_facility_id: nil, team_ids: [], citizen_id: nil
)
Cidadaobr::TenantContext.with(tenant) do
  ActiveRecord::Base.transaction do
    team = CareTeam.find_by!(municipality: m, team_kind: "esb")
    Indicators::RecalculateTeamScore.call(care_team: team)
  end
end
```

RLS na aplicação:

- **Leituras:** `TenantScopeMiddleware` + `TenantContext.with` → `SET app.current_*` (sessão).
- **Escritas:** qualquer `ActiveRecord::Base.transaction` (inclui `#save`) reaplica `SET LOCAL` via `config/initializers/tenant_rls_transaction.rb`.
- **Console:** sempre `Cidadaobr::TenantContext.with(tenant) { ... }`.
- **Teste:** usuário `postgres` ignora RLS — use `cidadaobr_app` em development ou veja `spec/models/tenant_rls_spec.rb`.
