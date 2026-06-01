# Checklist de piloto — primeira prefeitura

**Objetivo:** validar que a plataforma gera **decisão operacional** (não só demo técnica) em **90 dias**.

---

## Antes de assinar (comercial / jurídico)

- [ ] Contrato descreve **MVP Fase 4** (ver [one-pager-mvp-piloto.md](one-pager-mvp-piloto.md))
- [ ] Cláusula explícita: **projeção de repasse = estimativa**, não valor oficial
- [ ] Definido: 1 município, quantas UBS, quantas equipes (ESF + eSB + eMulti se houver)
- [ ] Ponto focal na secretaria (gestor) + ponto focal de TI/dados
- [ ] Acesso ao fluxo de exportação LEDI do PEC/e-SUS da prefeitura acordado
- [ ] LGPD: base legal e responsável pelo tratamento de dados de saúde definidos

---

## Semana 0–2 — Implantação base

- [ ] Ambiente disponível (cloud ou on-prem conforme contrato)
- [ ] Município e UBS cadastrados
- [ ] Usuários criados: secretário, gestor UBS, recepção, TI
- [ ] **Equipes com tipo correto:** ESF, eSB, eMulti (crítico para indicadores B e M)
- [ ] Primeira carga de cidadãos/domicílios (importação ou cadastro mínimo)
- [ ] Primeiro lote LEDI importado com sucesso
- [ ] Treinamento 2h: navegação + painel de indicadores + agenda

---

## Semana 3–6 — Dados e confiança

- [ ] Importação LEDI recorrente (frequência acordada: diária ou semanal)
- [ ] Taxa de fichas válidas vs rejeitadas monitorada
- [ ] Cidadãos vinculados a equipes (denominador dos indicadores coerente)
- [ ] Gestor valida amostra: “estes 10 cidadãos pendentes fazem sentido?”
- [ ] Ajustes de cadastro (equipe errada, UBS errada) documentados
- [ ] Agenda em uso na recepção de pelo menos 1 UBS piloto

---

## Fase 5 — Campanhas e rotas (web gestão)

Validação técnica automatizada: `bundle exec rspec spec/requests/web/stock_and_campaigns_spec.rb spec/lib/inventory/reserve_visit_route_supplies_spec.rb`

- [ ] **Campanha domiciliar:** público-alvo → gerar rotas → calcular/reservar provisionamento → publicar rotas → despachar kit (UI)
- [ ] **Campanha vacinação:** wizard 4 passos → aprovar provisionamento → publicar (UI)
- [ ] Romaneio de insumos (`/web/stock/team_supply_dispatches`) conferido com gestor UBS
- [ ] Mapa de rotas (`route_map`) usado para revisar paradas do dia

Logins seed: ver [piloto-validacao-tecnica.md](piloto-validacao-tecnica.md).

---

## Semana 7–12 — Uso e resultado

- [ ] Reunião quinzenal gestor + CidadãoBR: indicadores vermelhos e plano de ação
- [ ] 3 indicadores prioritários escolhidos pela secretaria (ex.: C1, C3, B1)
- [ ] Meta piloto: reduzir gaps nesses 3 indicadores (número acordado antes)
- [ ] Relatório de ocupação/absenteísmo usado em pelo menos 1 reunião de equipe
- [ ] Feedback formal: o que falta para virar contrato anual / expansão de UBS

---

## Critérios de “piloto aprovado” (go/no-go para escala)

| Critério | Go | No-go |
|----------|-----|-------|
| Dados LEDI entram de forma estável | Sim | Não consegue importar |
| Painel reflete realidade local (amostra validada) | Sim | Gestor não confia nos números |
| Pelo menos 1 ação operacional tomada por causa do painel | Sim | Só “olharam”, nada mudou |
| Equipes tipadas e indicadores B/M aparecem quando aplicável | Sim | Tudo zerado por configuração |
| Secretaria quer continuar pagando | Sim | “Voltamos para planilha” |

---

## Riscos a monitorar no piloto (CEO)

1. **Expectativa de repasse oficial** — mitigar com disclaimer e foco em “priorização”, não em R$ garantido
2. **Dados ruins no e-SUS** — produto amplifica qualidade do cadastro; piloto pode expor problema pré-existente
3. **Equipe sem tipo (eSB/eMulti)** — indicadores odonto/eMulti não aparecem corretamente
4. **Champion ausente** — sem gestor usando o painel, piloto morre
5. **Escopo creep** — pedidos de campanha/app cidadão antes de fechar Fase 4 no terreno
