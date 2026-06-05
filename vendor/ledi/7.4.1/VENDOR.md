# LEDI APS 7.4.1 vendor artifacts

Source: [laboratoriobridge/esusaps-integracao](https://github.com/laboratoriobridge/esusaps-integracao)

- Pinned ref: see `SYNC.sha` and `source_content_sha256` in `config/ledi.yml`
- `SOURCE_CONTENT_SHA256` fingerprints vendored files; `SOURCE_COMMIT` is the upstream git SHA when known
- Thrift compiler: 0.9.2–0.9.3 (generated Ruby under `gen-rb/`)
- Layouts vendored:
  - `thrift/dado_transporte.thrift` (camada de transporte)
  - `gen-rb/` from `thrift/layout-camada-transport` and `thrift/layout-ras`

## Upgrade procedure

1. Check LEDI/PEC compatibility table on [integracao.esusab.ufsc.br](https://integracao.esusab.ufsc.br).
2. Pull matching commit from `esusaps-integracao`.
3. Regenerate Ruby stubs with the repo script `thrift_build_with_docker.sh` or copy updated `gen-rb/`.
4. Update `config/ledi.yml` version, commit SHA, and `serialized_types` if new fichas were added.
5. Run `bundle exec rspec spec/lib/ledi`.
