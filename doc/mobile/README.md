# Mobile repositories (Opção A)

Flutter apps **não** vivem neste repositório. Após clonar `cidadaobr`, crie os repositórios irmãos no mesmo diretório pai:

```bash
cd ~/Development/Projects/cidadaobr
chmod +x doc/mobile/bootstrap_sibling_repos.sh
./doc/mobile/bootstrap_sibling_repos.sh
# then: git init in each sibling directory as needed
```

## Contrato API

- OpenAPI: [../api/openapi.v1.yaml](../api/openapi.v1.yaml)
- ADR: [../../docs/adr/0002-multi-repo-mobile-and-api-contracts.md](../../docs/adr/0002-multi-repo-mobile-and-api-contracts.md)
- Gerar client Dart (exemplo):

```bash
cd cidadaobr-mobile-shared
dart pub global activate openapi_generator
# apontar para ../cidadaobr/doc/api/openapi.v1.yaml
```

## MVP `cidadaobr-citizen`

Telas mínimas do Sprint 5:

1. Login (`POST /api/v1/citizen/auth`)
2. Lista de consultas
3. Slots + agendamento
4. Carteira vacinal

Variável de ambiente: `CIDADAOBR_API_BASE_URL` (ex. `http://10.0.2.2:3000` no emulador Android).

## `cidadaobr-field`

Criar apenas na Fase 5–6 (EPIC-08); não inicializar junto com o citizen MVP.
