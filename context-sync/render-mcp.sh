#!/usr/bin/env bash
# render-mcp.sh — Render a host-portable .mcp.json from mcp.json.template.
#
# The committed template carries ${HOME} / ${PROJECTS_ROOT} tokens; this script
# expands them to absolute paths for THIS host and writes the result to
# $PROJECTS_ROOT/.mcp.json (gitignored). Absolute paths at runtime are required:
# relative paths silently broke the anderson MCP from subdirs (fixed 2026-05-05),
# so the rendered file deliberately contains no tokens or relative paths.
#
# Idempotent: only writes when the rendered content differs from what's on disk.
#
# Usage:
#   bash render-mcp.sh            # render for this host
#   PROJECTS_ROOT=/path bash render-mcp.sh   # explicit workspace root
#
# Called by install.sh; safe to run standalone.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE="$SCRIPT_DIR/mcp.json.template"

# Workspace-root discovery: env override, then conventional fallback.
# Contract: 00_SYSTEM/anders-config/rules/workspace-root-discovery.md.
PROJECTS_ROOT="${PROJECTS_ROOT:-$HOME/Code/my-projects}"

[[ -f "$TEMPLATE" ]] || { echo "render-mcp: template not found: $TEMPLATE" >&2; exit 1; }

# No workspace on this host → nothing to render. Not an error (e.g. a host that
# clones dotfiles but not my-projects).
if [[ ! -d "$PROJECTS_ROOT" ]]; then
  echo "render-mcp: PROJECTS_ROOT not present ($PROJECTS_ROOT) — skipping .mcp.json render"
  exit 0
fi

OUT="$PROJECTS_ROOT/.mcp.json"

# Token expansion via bash parameter substitution (no envsubst dependency).
# Tokens are distinct literal strings, so substitution order is irrelevant.
content="$(cat "$TEMPLATE")"
content="${content//\$\{PROJECTS_ROOT\}/$PROJECTS_ROOT}"
content="${content//\$\{HOME\}/$HOME}"

# Idempotent write: skip if unchanged.
if [[ -f "$OUT" ]] && [[ "$(cat "$OUT")" == "$content" ]]; then
  echo "render-mcp: $OUT already current — no change"
  exit 0
fi

# Write to a temp first, validate as JSON, then move into place — so a malformed
# render (e.g. a path containing a quote/backslash) never clobbers a good .mcp.json.
tmp="$(mktemp "${OUT}.XXXXXX")"
trap 'rm -f "$tmp"' EXIT
printf '%s\n' "$content" > "$tmp"

if command -v python3 >/dev/null 2>&1; then
  python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$tmp" 2>/dev/null \
    || { echo "render-mcp: ERROR rendered config is not valid JSON — $OUT left unchanged" >&2; exit 1; }
elif command -v jq >/dev/null 2>&1; then
  jq empty "$tmp" 2>/dev/null \
    || { echo "render-mcp: ERROR rendered config is not valid JSON — $OUT left unchanged" >&2; exit 1; }
fi

mv "$tmp" "$OUT"
trap - EXIT
echo "render-mcp: wrote $OUT"
