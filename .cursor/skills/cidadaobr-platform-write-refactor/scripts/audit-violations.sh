#!/usr/bin/env bash
# Quick drift scan for ADR-0006 platform write contract. Review hits manually; not all are violations.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../../../" && pwd)"
cd "$ROOT"

USE_RG=false
if command -v rg >/dev/null 2>&1; then
  USE_RG=true
fi

search_controllers() {
  local pattern="$1"
  if $USE_RG; then
    rg -n "$pattern" app/controllers --glob '*.rb' || true
  else
    grep -rnE "$pattern" app/controllers --include='*.rb' 2>/dev/null || true
  fi
}

search_lib_app() {
  local pattern="$1"
  if $USE_RG; then
    rg -o "$pattern" lib app -g '*.rb' --no-filename 2>/dev/null || true
  else
    grep -rohE "$pattern" lib app --include='*.rb' 2>/dev/null || true
  fi
}

file_has_record_platform_event() {
  local file="$1"
  if $USE_RG; then
    rg -q 'RecordPlatformEvent' "$file"
  else
    grep -q 'RecordPlatformEvent' "$file" 2>/dev/null
  fi
}

mapping_has_event_type() {
  local et="$1"
  local mapping="$ROOT/app/services/outbox_publisher.rb"
  if $USE_RG; then
    rg -q "\"$et\"" "$mapping"
  else
    grep -q "\"$et\"" "$mapping" 2>/dev/null
  fi
}

echo "=== Platform write audit ($(date -Iseconds)) ==="
echo "Repo: $ROOT"
if $USE_RG; then
  echo "Search: ripgrep (rg)"
else
  echo "Search: grep (install ripgrep for faster audits: apt install ripgrep)"
fi
echo

echo "--- Controllers: create/save/update/destroy! ---"
search_controllers '\.(create|update|save|destroy)!'
echo

echo "--- Controllers: direct SomeCommand.call (prefer CommandBus.dispatch) ---"
search_controllers '::[A-Za-z:]+(\.|::)[A-Za-z]+\.call'
echo

echo "--- Commands without RecordPlatformEvent (lib/**/commands) ---"
missing_events=0
while IFS= read -r f; do
  if ! file_has_record_platform_event "$f"; then
    echo "  $f"
    missing_events=$((missing_events + 1))
  fi
done < <(find lib -path '*/commands/*.rb' -type f 2>/dev/null | sort)
if [ "$missing_events" -eq 0 ]; then
  echo "  (none)"
fi
echo

echo "--- event_type in code not in TOPIC_MAPPING (heuristic) ---"
MAPPING="$ROOT/app/services/outbox_publisher.rb"
unmapped=0
while IFS= read -r et; do
  [ -z "$et" ] && continue
  if ! mapping_has_event_type "$et"; then
    echo "  missing mapping?: $et"
    unmapped=$((unmapped + 1))
  fi
done < <(
  search_lib_app 'event_type:[[:space:]]*"[a-z0-9._]+"' \
    | sed -n 's/.*event_type:[[:space:]]*"\([^"]*\)".*/\1/p' \
    | sort -u
)
if [ "$unmapped" -eq 0 ]; then
  echo "  (none detected)"
fi
echo

echo "--- Summary ---"
echo "Review hits above; optional events are OK per ADR-0006."
echo "Docs: docs/adr/0006-platform-write-contract.md"
echo "Done."
