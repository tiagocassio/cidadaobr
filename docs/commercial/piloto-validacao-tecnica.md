# Validação técnica — ambiente demo (pós-seed)

Checklist manual (~30 min) após `bin/rails db:seed` em ambiente de desenvolvimento ou piloto.

## Pré-requisitos

```bash
docker compose up -d postgres
bin/rails db:migrate
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

Operações tenant-scoped devem rodar dentro de `ActiveRecord::Base.transaction` para que políticas RLS reconheçam o escopo (`SET LOCAL`).
