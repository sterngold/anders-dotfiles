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
  "$HOME_DIR/.claude-full/statusline.sh"
  "$HOME_DIR/.claude-full/keybindings.json"
  "$HOME_DIR/.claude-full/skills"
  "$HOME_DIR/.claude-full/agents"
  "$HOME_DIR/.codex/AGENTS.md"
)

# Track the LOWEST failing-class code so the result matches the header's
# "first failing class in listed order" contract regardless of check order.
fail_code=0
note_fail() { local code="$1"; shift; echo "  ✗ [$code] $*"; { [[ $fail_code -eq 0 ]] || (( code < fail_code )); } && fail_code="$code"; }
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
  # Extract line-start '@<path>' import tokens (column-0 only — Claude Code and
  # this scan both ignore indented/back-ticked @-paths).
  mapfile -t IMPORTS < <(grep -oE '^@[^[:space:]]+' "$ROUTER" | sed 's/^@//')
  if [[ ${#IMPORTS[@]} -eq 0 ]]; then
    note_ok "router has no @imports to resolve"
  fi
  for imp in "${IMPORTS[@]}"; do
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
  done
else
  note_fail 11 "router not found: $ROUTER"
fi

# --- 12: leaked host-specific absolute literals -----------------------------
# NOTE: substring scan — it also matches an absolute path written in PROSE
# (e.g. documenting "never use /Users/..."). Committed context files must
# describe such paths WITHOUT the literal (see claude/CLAUDE.md's vault section).
echo "[literals]"
leak_re='/Users/|/home/[^/]+/'
for f in "${COMMITTED_CONTEXT[@]}"; do
  [[ -e "$f" ]] || continue                 # not present on this host — nothing to scan
  if [[ ! -r "$f" ]]; then
    note_fail 12 "cannot read committed file (treat as suspect): $f"; continue
  fi
  # Branch on grep's THREE states: 0=found, 1=clean, >1=error. Folding error
  # into "clean" would let this safety check pass vacuously on an unreadable file.
  hits="$(grep -nE "$leak_re" "$f")"; rc=$?
  case $rc in
    0) note_fail 12 "leaked absolute path in committed file: $f"; printf '%s\n' "$hits" | sed 's/^/      /' ;;
    1) note_ok "no leaked literals: ${f#$REPO/}" ;;
    *) note_fail 12 "grep errored (rc=$rc) scanning $f — cannot verify" ;;
  esac
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
