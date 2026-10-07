#!/usr/bin/env bash
# Enforces RULES.md §2: no .dart file under lib/ or test/ may exceed 500
# lines (generated files are exempt). Fails with exit 1 and lists every
# offender when the limit is exceeded.

set -euo pipefail

readonly MAX_LINES=500
readonly ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

offenders=()

while IFS= read -r -d '' file; do
  line_count=$(wc -l < "$file")
  if [ "$line_count" -gt "$MAX_LINES" ]; then
    offenders+=("$file:$line_count")
  fi
done < <(find "$ROOT_DIR/lib" "$ROOT_DIR/test" -type f -name '*.dart' \
  ! -name '*.g.dart' \
  ! -path '*/l10n/app_localizations*.dart' \
  -print0 2>/dev/null)

if [ "${#offenders[@]}" -gt 0 ]; then
  echo "The following files exceed the ${MAX_LINES}-line limit (RULES.md #2):"
  for offender in "${offenders[@]}"; do
    echo "  - $offender"
  done
  exit 1
fi

echo "OK: no .dart file under lib/ or test/ exceeds ${MAX_LINES} lines."
