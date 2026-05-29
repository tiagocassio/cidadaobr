#!/usr/bin/env bash
# Scaffold sibling Flutter repos (Opção A). Run from repo root: ./doc/mobile/bootstrap_sibling_repos.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PARENT="$(dirname "$ROOT")"

SHARED="${PARENT}/cidadaobr-mobile-shared"
CITIZEN="${PARENT}/cidadaobr-citizen"

mkdir -p "${SHARED}/packages/api_client/lib" "${CITIZEN}/lib"

if [[ ! -f "${SHARED}/pubspec.yaml" ]]; then
  cat > "${SHARED}/pubspec.yaml" <<'EOF'
name: cidadaobr_mobile_shared
description: Shared Dart packages for CidadãoBR Saúde mobile apps.
publish_to: none

environment:
  sdk: ">=3.5.0 <4.0.0"
EOF
  cat > "${SHARED}/packages/api_client/pubspec.yaml" <<'EOF'
name: api_client
description: OpenAPI client for CidadãoBR Saúde (generate from cidadaobr/doc/api/openapi.v1.yaml).
publish_to: none

environment:
  sdk: ">=3.5.0 <4.0.0"
EOF
  echo "# api_client" > "${SHARED}/packages/api_client/lib/api_client.dart"
  echo "Created ${SHARED}"
else
  echo "Skip ${SHARED} (already exists)"
fi

if [[ ! -f "${CITIZEN}/pubspec.yaml" ]]; then
  cat > "${CITIZEN}/pubspec.yaml" <<'EOF'
name: cidadaobr_citizen
description: CidadãoBR Saúde — app cidadão (MVP agenda e vacinas).
publish_to: none

environment:
  sdk: ">=3.5.0 <4.0.0"

dependencies:
  flutter:
    sdk: flutter
EOF
  mkdir -p "${CITIZEN}/lib"
  cat > "${CITIZEN}/lib/main.dart" <<'EOF'
import 'package:flutter/material.dart';

void main() {
  runApp(const CidadaobrCitizenApp());
}

class CidadaobrCitizenApp extends StatelessWidget {
  const CidadaobrCitizenApp({super.key});

  @override
  Widget build(BuildContext context) {
    const baseUrl = String.fromEnvironment(
      'CIDADAOBR_API_BASE_URL',
      defaultValue: 'http://10.0.2.2:3000',
    );
    return MaterialApp(
      title: 'CidadãoBR Saúde',
      home: Scaffold(
        appBar: AppBar(title: const Text('CidadãoBR Saúde')),
        body: Center(child: Text('API: $baseUrl')),
      ),
    );
  }
}
EOF
  echo "Created ${CITIZEN}"
else
  echo "Skip ${CITIZEN} (already exists)"
fi

echo ""
echo "Next: generate OpenAPI client in cidadaobr-mobile-shared (see doc/mobile/README.md)."
