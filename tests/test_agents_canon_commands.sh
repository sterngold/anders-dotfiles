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
# Literal Markdown contract text; backticks and emphasis markers must not expand.
# shellcheck disable=SC2016
grep -F 'Run the repository-specific **pre-PR validation** commands declared in Section 2 before opening a PR. Setup/install commands and operations explicitly labeled owner-only, live, preview, deploy, or publish are not pre-PR agent gates; never run them without the required context and approval. Never invent a generic `make` target or substitute a weaker command.' "$TMP/AGENTS.md" >/dev/null
# shellcheck disable=SC2016
if grep -F 'Run `make lint && make test` before opening a PR.' "$TMP/AGENTS.md" >/dev/null; then
  echo "generic make command leaked into assembled AGENTS.md" >&2
  exit 1
fi
