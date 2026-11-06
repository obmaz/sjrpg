#!/usr/bin/env bash
# Both editable projects are checked independently before assembling the portal.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT=all
EXPORT=0
ARGS=()
for ARG in "$@"; do
  case "$ARG" in
    --project=2d) PROJECT=2d ;;
    --project=3d) PROJECT=3d ;;
    --project=all) PROJECT=all ;;
    --export) EXPORT=1 ;;
    --only=*) ARGS+=("$ARG") ;;
    *) echo "Unknown option: $ARG" >&2; exit 2 ;;
  esac
done
for EDITION in 2d 3d; do
  if [[ "$PROJECT" != all && "$PROJECT" != "$EDITION" ]]; then continue; fi
  echo "Checking sjrpg_$EDITION"
  "$ROOT/sjrpg_$EDITION/tools/check.sh" "${ARGS[@]}"
done
if [[ "$EXPORT" == 1 ]]; then "$ROOT/tools/export_web.sh"; fi
