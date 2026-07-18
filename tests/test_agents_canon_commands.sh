#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/AGENTS.header.md" <<'EOF'
# AGENTS.md

## 1. Repo identity

- Repo: fixture

## 2. Build, test, lint

```bash
./scripts/verify.sh
```
EOF

bash "$ROOT/context-sync/assemble-agents.sh" "$TMP"
grep -F './scripts/verify.sh' "$TMP/AGENTS.md" >/dev/null
grep -F 'Run the repository-specific build, lint, test, and verification commands declared in Section 2 before opening a PR.' "$TMP/AGENTS.md" >/dev/null
if grep -F 'Run `make lint && make test` before opening a PR.' "$TMP/AGENTS.md" >/dev/null; then
  echo "generic make command leaked into assembled AGENTS.md" >&2
  exit 1
fi
