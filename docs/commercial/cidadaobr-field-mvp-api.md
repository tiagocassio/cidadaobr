# CidadãoBR Campo — MVP API (Fase 5)

Repositório irmão recomendado: `cidadaobr-field` (Flutter).

## Autenticação

`POST /api/v1/field/auth`

Corpo: `email`, `password`, `municipality_id`. Resposta inclui JWT usado como `Authorization: Bearer …`.

## Fila de campanhas

`GET /api/v1/field/campaigns` — campanhas domiciliares em `scheduled`, `active` ou `routes_generated`.

`GET /api/v1/field/campaigns/:id` — detalhe com contagem de alvos.

## Roteiros

`GET /api/v1/field/visit_routes` — rotas da equipe logada (escopo team) ou UBS (escopo facility).

`GET /api/v1/field/visit_routes/:id` — paradas ordenadas (`stop_order`) + checklist de provisionamento (`provisioning.lines`).

## Próximo passo no app Flutter

- Tela de fila (`campaigns#index`)
- Detalhe do roteiro com mapa/lista (`visit_routes#show`)
- Confirmação de kit de insumos (FIELD-10) — endpoint futuro `POST /api/v1/field/visit_routes/:id/confirm_supplies`

Contrato OpenAPI: estender `doc/api/openapi.v1.yaml` na próxima iteração.
