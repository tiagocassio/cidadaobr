# ADR 0001: Tenant isolation with PostgreSQL RLS and hierarchical keys

## Status

Accepted

## Context

CidadãoBR Saúde serves multiple municipalities and UBS units from a shared PostgreSQL 18 cluster. Each municipality must see only its data; each UBS must not read or mutate another UBS scope within the same municipality.

## Decision

- Use a single shared schema with `municipality_id NOT NULL` on operational tables.
- Use optional `health_facility_id` for UBS-scoped data.
- Enforce PostgreSQL Row Level Security (RLS) with session variables:
  - `app.current_municipality_id`
  - `app.current_scope`
  - `app.current_health_facility_id`
- Application RBAC via `user_municipality_memberships` complements RLS but does not replace it.
- Rails `default_scope` or controller-only filtering is forbidden for tenant isolation.

## Consequences

- Every request/job must set tenant session variables through `TenantScopeMiddleware` or `Cidadaobr::TenantContext.with`.
- Migrations must add RLS policies when introducing tenant-scoped tables.
- Facility-scoped users cannot access other facilities even in the same municipality.
- Municipal-scoped users can access all facilities in their municipality.
