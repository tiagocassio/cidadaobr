# EPIC-00 — Conformidade contínua (remediação)

**Objetivo:** toda mutação de domínio segue [ADR-0006](adr/0006-platform-write-contract.md).  
**Skill / regras:** `.cursor/skills/cidadaobr-platform-write-refactor/`, `.cursor/rules/platform-write-*.mdc`, `AGENTS.md`.

O backlog marca EPIC-00 `done` na **infra** (Fase 0); este documento é o **gate de conformidade do código**.

---

## Definição de pronto — “plataforma EPIC-00”

| # | Critério | Verificação |
|---|----------|-------------|
| 1 | Mutação operacional só em `lib/<context>/commands/` | `rg '\.(save|create|update)!?\(' app/controllers` → lista vazia (exceto allowlist) |
| 2 | Borda HTTP/API usa `CommandBus.dispatch` | Sem `SomeCommand.call` / AR em controllers de domínio |
| 3 | Eventos de integração com `RecordPlatformEvent` + `Cidadaobr::KafkaTopics` | Specs + tópicos em `bin/kafka_create_topics` (`event_type` = topic) |
| 4 | Tenant + transação | `with_tenant` nos specs; commands em transação AR (RLS via middleware/initializer) |
| 5 | Governança | PR checklist; ADR-0006 referenciado no README dev |

**Sem allowlist de controllers** para mutações de domínio (jun/2026): usuários municipais via `Platform::Commands::*`.

---

## Matriz de conformidade (2026-06-02)

| Contexto | Commands | CommandBus na borda | Eventos | Status |
|--------|----------|---------------------|---------|--------|
| **scheduling** | `lib/scheduling/commands/*` | Web + API citizen | appointment.* | **OK** |
| **ledi** | `lib/ledi/commands/*` | API field validate | clinical.*, ledi.* | **OK** |
| **indicators** | `lib/indicators/commands/*` | jobs/consumers | indicator.* | **OK** |
| **campaigns domiciliar** | routing + inventory + build targets | `HomeVisitCampaignsController` | campaign/route/supplies.* | **OK** (Onda B) |
| **campaigns vacina** | create/update/publish/invalidate/persist provisioning | `VaccinationCampaignsController` | targets.built, published, draft_invalidated, provisioning.approved | **OK** (Onda E) |
| **territory (cadastro)** | `lib/territory/commands/*` | citizens, households, members, animals | citizen.registered/updated | **OK** (Onda C) |
| **territory (ops)** | facilities, teams, micro_areas | controllers web | care_team.created/updated | **OK** (Onda H) |
| **platform (users)** | `lib/platform/commands/*` | `UsersController` | — (auth local) | **OK** (Onda H) |
| **inventory estoque** | lot + product commands | lots/products#create | lot.received | **OK** (Onda G) |
| **routing helpers** | clear/update provisioning | `CommandBus` em `HomeVisitCampaignsController` | eventos via commands chamados | **OK** |
| **reference (EPIC-12)** | `Reference::Commands::PublishRelease` | jobs | `reference-release-published` (platform outbox) | **OK** (S9) |

---

## Ondas

### Onda A — Governança

- [x] ADR-0006
- [x] Skill Cursor + `AGENTS.md`
- [x] Plano mestre / roteiro atualizados
- [x] Matriz de conformidade (este doc)
- [x] PR template + README dev
- [x] Gate CI — `bin/ci_controller_writes` (job `controller_writes_gate`)

### Onda B — Campanha domiciliar — **concluída**

Eventos + `CommandBus` em `HomeVisitCampaignsController`.

### Onda C — Cadastro web — **concluída (2026-06-02)**

| Command | Uso |
|---------|-----|
| `Territory::Commands::RegisterCitizen` | `CitizensController#create` |
| `Territory::Commands::UpdateCitizen` | `CitizensController#update` |
| `Territory::Commands::CreateHousehold` / `UpdateHousehold` | `HouseholdsController` |
| `Territory::Commands::LinkCitizenToHousehold` | `HouseholdMembersController#create` |
| `Territory::Commands::UnlinkHouseholdMember` | destroy member |
| `Territory::Commands::RegisterHouseholdAnimal` / `RemoveHouseholdAnimal` | animais FCD |

### Onda E — Campanha vacina + create domiciliar — **concluída (2026-06-02)**

- [x] `CreateVaccinationCampaign`, `UpdateVaccinationCampaign`, `PublishVaccinationCampaign`
- [x] `CreateHomeVisitCampaign`
- [x] `InvalidateVaccinationCampaignDraft` (substitui `invalidate_after_definition_change!`)
- [x] `Inventory::Commands::PersistVaccinationProvisioning` (wizard passo 3; `ProvisioningValidator.persist!` delega)
- [x] `CommandBus` em build targets, publish, invalidate, provisioning

### Onda F — Agenda / APIs — **concluída**

`CommandBus` em `AppointmentsController`, API citizen appointments, API field validate.

### Onda G — Estoque — **concluída**

- [x] `ReceiveImmunobiologicalLot`, `CreateImmunobiologicalProduct`, `UpdateImmunobiologicalProduct`

### Onda H — Ops admin — **concluída (2026-06-02)**

| Command | Controller |
|---------|------------|
| `CreateHealthFacility` / `UpdateHealthFacility` | `HealthFacilitiesController` |
| `CreateCareTeam` / `UpdateCareTeam` | `CareTeamsController` (+ eventos) |
| `CreateMicroArea` / `UpdateMicroArea` | `MicroAreasController` |
| `RegisterMunicipalUser` / `UpdateMunicipalUser` | `UsersController` |

### Onda I — Homogeneidade — **concluída (2026-06-02)**

- [x] Commands `class << self` → `ApplicationCommand` (campaigns/routing/inventory/indicators legado)
- [x] `write_transaction` via `ApplicationCommand` (substitui `ActiveRecord::Base.transaction` em `lib/**/commands`)

**Gate CI:** `bin/ci_controller_writes` (job `controller_writes_gate` em `.github/workflows/ci.yml`).

### Onda J — Kafka consumers — **concluída (2026-06-02)**

Política publish-only documentada em [ADR-0007](adr/0007-kafka-topic-consumer-policy.md). Tópicos de campanha/cadastro/vacina publicam no Kafka; consumers de negócio = **Fase 8** salvo novo ADR.

---

## Gate Fase 6 clínica

- [x] Onda B
- [x] Onda C (cadastro web)
- [x] Onda H (UBS, equipe, microárea, usuários)
- [x] EPIC-12 S9 — platform outbox + `reference-release-published` ([ADR-0008](adr/0008-platform-scoped-outbox.md))
- [ ] EPIC-12 gate completo (fixtures CI PNI / competência SIGTAP em prod)
- [ ] ADR-0006 aceito formalmente pelo time

---

## Auditoria rápida

```bash
bin/ci_controller_writes   # gate CI (obrigatório em PR)
.cursor/skills/cidadaobr-platform-write-refactor/scripts/audit-violations.sh
bundle exec rspec spec/lib/territory/ spec/requests/web/citizens_spec.rb
```

---

## Próximo passo de engenharia

1. Piloto UI Fase 5 — checklist prefeitura.  
2. EPIC-12 — fixtures CI / import SIGTAP real (gate Fase 6).  
3. Fase 6 clínica.

Roteiro produto: [roteiro-organizado-fases-epicos.md](roteiro-organizado-fases-epicos.md).
