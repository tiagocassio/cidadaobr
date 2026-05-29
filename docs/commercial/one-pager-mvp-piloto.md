# One-pager comercial — CidadãoBR Saúde

**Para:** CEO, acionistas, secretários de saúde, compradores  
**Produto:** plataforma municipal de APS alinhada à Portaria GM/MS nº 3.493/2024  
**Versão:** maio/2026 (MVP Fase 4 entregue)

---

## Proposta de valor (uma frase)

A CidadãoBR ajuda a prefeitura a **saber, antes do fechamento do quadrimestre, quais indicadores estão em risco, quais cidadãos precisam de ação e quais equipes puxar** — com base nos mesmos dados do e-SUS (LEDI), sem substituir o PEC.

---

## O problema que você vende

| Dor da prefeitura | Como a plataforma responde hoje |
|-------------------|----------------------------------|
| “Só descobrimos a nota quando o MS publica” | Painel com desempenho por indicador e por equipe, atualizado conforme entram fichas |
| “Não sabemos quem falta atender para bater a meta” | Lista de pendências (gaps) por cidadão e por indicador |
| “Cada UBS opera no escuro” | Ranking de equipes e visão consolidada do município |
| “Dados espalhados no e-SUS” | Importação LEDI + vínculo cidadão–equipe–território |

---

## O que entra no contrato (MVP vendável hoje)

Use isto como **escopo mínimo de piloto ou contrato inicial**.

### Incluído — pronto para operação

1. **Plataforma web municipal** (multi-UBS, perfis de acesso)
2. **Cadastro operacional:** UBS, equipes, microáreas, cidadãos, domicílios, mapa territorial
3. **Integração LEDI 7.4.0:** recebimento e validação de fichas clínicas (base e-SUS APS)
4. **Agenda UBS:** marcação, recepção, check-in, falta (no-show), relatório de ocupação
5. **Motor dos 17 indicadores** (Portaria 3.493 / notas SAPS):
   - Vínculo: CVAT, V_CAD, V_ACOMP, V_SAT
   - Qualidade ESF/eAP: C1–C7
   - Saúde bucal: B1–B6
   - eMulti: M1–M2
6. **Painel do gestor:**
   - visão X/17 indicadores no quadrimestre
   - ranking de equipes
   - drill-down de pendências por cidadão
   - projeção de repasse **estimada** (com disclaimer: não é cálculo oficial do Ministério)
7. **API documentada** (OpenAPI) para evolução futura (app cidadão / campo)

### Incluído com ressalvas (transparente no contrato)

| Item | O que prometer | O que não prometer |
|------|----------------|---------------------|
| Projeção de repasse em R$ | “Estimativa para planejamento interno” | “Valor oficial igual ao SIAPS/Ministério” |
| Indicadores B/M | Score e pendências operacionais | Réplica 100% idêntica ao algoritmo federal em todos os casos |
| B3 (exodontias) | Métrica de **equipe** no painel | Pendência individual por cidadão |
| Equipes eSB/eMulti | Filtro correto após cadastro do **tipo da equipe** | Funciona “sozinho” sem configuração municipal |

---

## O que fica no roadmap (fora do contrato MVP)

Organize em **fases comerciais** — upsell ou fase 2 do contrato:

| Fase | Entrega | Valor para a prefeitura | Status |
|------|---------|-------------------------|--------|
| **Fase A — Credibilidade financeira** | Repasse com coeficientes oficiais; conciliação SIAPS | “Nosso número bate com o do MS” | Roadmap |
| **Fase B — Cidadão** | App do munícipe (agenda, vacinas, etc.) | Engajamento e redução de absenteísmo | Parcial (API ok; app em repo separado) |
| **Fase C — Campo** | App profissional, multirão, fichas offline | Produção ACS/ESF no território | Não iniciado |
| **Fase D — Campanhas** | Vacinação em massa, rotas de visita, estoque/kits | Operação de campanha integrada aos indicadores | Não iniciado |
| **Fase E — PEC pleno + IA** | Envio/homologação completa; inteligência e relatórios avançados | Escala e diferencial tecnológico | Futuro |

**Mensagem para investidor:** o **core de receita inicial** (indicadores + gestão) está construído; o **ARR expansível** vem das fases B–E.

---

## Posicionamento comercial recomendado

| Perfil de venda | Pitch |
|-----------------|-------|
| **Piloto (6–12 meses)** | “Diagnóstico e priorização de indicadores 3.493 — 1 município, N UBS” |
| **Contrato SaaS anual** | “Gestão de desempenho APS + agenda + integração LEDI” |
| **Não vender ainda** | “Substituímos o e-SUS/PEC” ou “Garantimos o repasse federal” |

---

## KPIs de sucesso do piloto (para board)

1. **Cobertura de dados:** ≥ 80% das equipes com importação LEDI ativa no 1º mês
2. **Uso do painel:** gestor acessa indicadores ≥ 1× por semana
3. **Ação:** redução de gaps abertos nos 3 indicadores prioritários da secretaria em 90 dias
4. **Satisfação:** secretário confirma que o painel “antecipa” o que antes só via no fim do quadrimestre
5. **Honestidade:** nenhuma decisão financeira tomada só com a projeção ilustrativa (usar como direção, não como OF)
