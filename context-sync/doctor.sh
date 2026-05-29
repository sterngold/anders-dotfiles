#!/usr/bin/env bash
# doctor.sh — Validate that this host's portable AI-context layer is sound.
#
# Checks symlink health, @import targets, leaked absolute-path literals in
# committed context files, vault presence, and the rendered .mcp.json.
#
# Reports ALL findings, then exits with a DISTINCT code per failure class so
# callers (and CI) can branch on the cause. Exit codes (first failing class
# in listed order wins; 0 = all green):
#   10  broken symlink (managed home symlink target missing)
#   11  missing @import target referenced by a committed router
#   12  host-specific absolute path literal leaked into a committed file
#   13  ~/Vaults referenced by a router but absent on this host
#   14  rendered .mcp.json missing (workspace present but never rendered)
#
# Usage: bash doctor.sh   (or: make doctor)

set -uo pipefail   # NOT -e: we want to run every check and aggregate.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$SCRIPT_DIR/.." && pwd)"
HOME_DIR="${HOME}"
PROJECTS_ROOT="${PROJECTS_ROOT:-$HOME/Code/my-projects}"

ROUTER="$REPO/claude/CLAUDE.md"

# Committed context files to scan for leaked literals (token/~/$VAR only).
COMMITTED_CONTEXT=(
  "$REPO/context-sync/mcp.json.template"
  "$REPO/claude/CLAUDE.md"
  "$REPO/claude/RTK.md"
)

# Managed home symlinks install.sh creates (skip ones not present on this host).
MANAGED_LINKS=(
  "$HOME_DIR/.claude-full/CLAUDE.md"
  "$HOME_DIR/.claude-full/RTK.md"
  "$HOME_DIR/.codex/AGENTS.md"
)

fail_code=0        # remembers the FIRST failing class (lowest-in-order)
note_fail() { local code="$1"; shift; echo "  ✗ [$code] $*"; [[ $fail_code -eq 0 ]] && fail_code="$code"; }
note_ok()   { echo "  ✓ $*"; }

echo "context doctor — host=$(uname -s) HOME=$HOME_DIR PROJECTS_ROOT=$PROJECTS_ROOT"

# --- 10: symlink health -----------------------------------------------------
echo "[symlinks]"
for link in "${MANAGED_LINKS[@]}"; do
  if [[ -L "$link" ]]; then
    if [[ -e "$link" ]]; then note_ok "$link -> $(readlink "$link")"
    else note_fail 10 "broken symlink: $link -> $(readlink "$link") (target missing)"; fi
  fi
done

# --- 11 / 13: @import targets + vault presence ------------------------------
echo "[imports]"
if [[ -f "$ROUTER" ]]; then
  # Extract '@<path>' import tokens (ignore email-like and code-fenced noise).
  while IFS= read -r imp; do
    [[ -z "$imp" ]] && continue
    # Expand leading ~ and resolve relative imports against the router's dir.
    case "$imp" in
      "~/"*) target="$HOME_DIR/${imp#\~/}" ;;
      "/"*)  target="$imp" ;;
      *)     target="$(dirname "$ROUTER")/$imp" ;;
    esac
    if [[ -e "$target" ]]; then
      note_ok "@$imp -> $target"
    else
      case "$imp" in
        "~/Vaults/"*) [[ -d "$HOME_DIR/Vaults" ]] \
            && note_fail 11 "missing import: @$imp" \
            || note_fail 13 "vault import @$imp but ~/Vaults absent" ;;
        *) note_fail 11 "missing import: @$imp" ;;
      esac
    fi
  done < <(grep -oE '^@[^[:space:]]+' "$ROUTER" | sed 's/^@//')
else
  note_fail 11 "router not found: $ROUTER"
fi

# --- 12: leaked host-specific absolute literals -----------------------------
echo "[literals]"
leak_re='/Users/|/home/[^/]+/'
for f in "${COMMITTED_CONTEXT[@]}"; do
  [[ -f "$f" ]] || continue
  if grep -nE "$leak_re" "$f" >/dev/null 2>&1; then
    note_fail 12 "leaked absolute path in committed file: $f"
    grep -nE "$leak_re" "$f" | sed 's/^/      /'
  else
    note_ok "no leaked literals: ${f#$REPO/}"
  fi
done

# --- 14: rendered .mcp.json -------------------------------------------------
echo "[mcp]"
if [[ -d "$PROJECTS_ROOT" ]]; then
  if [[ -f "$PROJECTS_ROOT/.mcp.json" ]]; then note_ok "rendered: $PROJECTS_ROOT/.mcp.json"
  else note_fail 14 "workspace present but $PROJECTS_ROOT/.mcp.json not rendered (run render-mcp.sh)"; fi
else
  note_ok "no workspace on this host ($PROJECTS_ROOT) — .mcp.json not required"
fi

echo ""
if [[ $fail_code -eq 0 ]]; then echo "doctor: all green ✓"; else echo "doctor: FAILED (exit $fail_code)"; fi
exit "$fail_code"
