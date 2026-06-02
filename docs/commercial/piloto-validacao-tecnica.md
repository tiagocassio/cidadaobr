# Validação técnica — ambiente demo (pós-seed)

Checklist manual (~30 min) após `bin/rails db:seed` em ambiente de desenvolvimento ou piloto.

## Pré-requisitos

```bash
docker compose up -d postgres
bin/setup --skip-server
# ou, se o banco já existir mas cidadaobr_app falhar:
# POSTGRES_APP_USER=postgres POSTGRES_APP_PASSWORD=postgres \
# POSTGRES_SCHEMA_USER=postgres POSTGRES_SCHEMA_PASSWORD=postgres \
# CIDADAOBR_APP_ROLE_PASSWORD=cidadaobr_app bin/rails db:prepare
bin/rails db:seed
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

Specs automatizados (gate): `bundle exec rspec` — suite verde (jun/2026). Campanhas: `spec/requests/web/stock_and_campaigns_spec.rb` (19 examples, fluxo domiciliar + wizard vacina via HTTP).

Banco local: recriar do zero com `docker compose exec -T postgres psql -U postgres -c 'DROP DATABASE ...'` + `bin/rails db:migrate` (schema gerado só das migrations; `supply_items.code` correto).

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
