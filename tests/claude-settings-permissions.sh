#!/usr/bin/env bash

# Claude Code 2.1.210 no longer applies path permission rules written as
# Write(path). Edit(path) covers every file-editing tool, so retaining Write(...)
# creates startup warnings while adding no protection.

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FILES=(
  "$REPO/context-sync/managed-settings.json.template"
  "$REPO/claude-full/settings.json"
  "$REPO/claude/settings.json"
  "$REPO/claude-build/settings.json"
  "$REPO/claude-partner/settings.json"
)

failed=0
for file in "${FILES[@]}"; do
  if hits="$(grep -n '"Write(' "$file")"; then
    echo "obsolete Claude Write(path) permission rule: ${file#"$REPO"/}" >&2
    printf '%s\n' "$hits" | sed 's/^/  /' >&2
    failed=1
  fi
done

if (( failed )); then
  exit 1
fi

echo "Claude settings permission syntax: OK"
