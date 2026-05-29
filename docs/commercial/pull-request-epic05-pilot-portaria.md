# Pull request — EPIC-05 pilot + Portaria 3.493 + Fase 5 kickoff

**Branch:** `chore/epic05-pilot-seed-and-commercial-docs`  
**Base:** `main`

## Title

feat: Portaria 3.493 alignment, pilot docs, and EPIC-06 inventory/campaigns MVP

## Summary

- Align indicator catalog, seed, validations, and UI with official Portaria GM/MS 3.493/2024 via `Indicators::Portaria3493`.
- CVAT uses fixed MS weights (0,3 + 0,7) and V_SAT bonus (max 10 pts); V_CAD gap rules for V_CAD_ATU and V_LIM_CAD resolvers.
- Dashboard gap counts scoped to `IndicatorCatalog.active_portaria`.
- TASK-05-07: repasse coefficients load from `config/indicators/repasse_coefficients.yml` (example shipped).
- EPIC-06 kickoff: inventory/campaign schema, models, RLS, `Inventory::ProvisioningValidator`, WEB-STOCK/CAMP UI.
- Commercial: CEO decision Opção A, pilot execution log, PR test plan.

## Commits (on branch before this work)

1. `chore(pilot): seed typed care teams and add commercial docs`
2. `feat(indicators): align catalog to Portaria GM/MS 3.493/2024`

## Test plan

- [x] `bundle exec rspec spec/lib/indicators/ spec/lib/inventory/ spec/models/indicator* spec/db/indicator_catalog_seed_spec.rb` (66 examples, 0 failures)
- [x] `bin/rails db:migrate db:seed`
- [x] 4 demo teams ESF×2, eSB×1, eMulti×1
- [x] 19 Portaria indicators + inventory seed
- [ ] Manual UI: [`docs/commercial/piloto-validacao-tecnica.md`](piloto-validacao-tecnica.md)

## Create PR

```bash
git push -u origin chore/epic05-pilot-seed-and-commercial-docs
gh pr create --base main --title "feat: Portaria 3.493, pilot docs, EPIC-06 kickoff" --body-file docs/commercial/pull-request-epic05-pilot-portaria.md
```

**Note:** Requires `git remote` and `gh` CLI configured on the workstation.
