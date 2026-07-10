#!/usr/bin/env bash
# assemble-sweep.sh — non-mutating drift report across every AGENTS.md-canonical repo.
#
# Runs `assemble-agents.sh --check` against the fixed roster of repos on the
# AGENTS.md-canonical pipeline (the "done" table in context-sync/AGENTS-CANON-STATUS.md)
# and reports one line per repo: PASS / STALE / ERROR / MISSING. Never writes
# anything — pure read-only sweep, safe to run from doctor.sh or ad hoc.
#
# The workspace root (my-projects) is the documented intentional exception
# (hand-written canon, NOT assembled) and is deliberately absent from this roster.
#
# A repo path absent on THIS host is reported MISSING, not a failure — hosts
# differ (BabyStar vs AndersStar, client machines, CI runners, etc.).
#
# Usage: bash assemble-sweep.sh
# Exit:  0 = every present repo PASS · 1 = at least one STALE or ERROR

set -uo pipefail   # NOT -e: one repo's non-zero --check must not kill the loop.

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASSEMBLE="$SELF_DIR/assemble-agents.sh"
PROJECTS_ROOT="${PROJECTS_ROOT:-$HOME/Code/my-projects}"

if [[ ! -f "$ASSEMBLE" ]]; then
  echo "assemble-sweep: ERROR — assemble-agents.sh not found at $ASSEMBLE" >&2
  exit 2
fi

# Fixed roster — from AGENTS-CANON-STATUS.md's "done" table. my-projects root
# is the documented intentional exception; never add it here.
REPOS=(
  "$PROJECTS_ROOT/00_SYSTEM/anders-config"
  "$HOME/anders-dotfiles"
  "$PROJECTS_ROOT/10_AI_OS/AndersMem"
  "$PROJECTS_ROOT/20_PRODUCTS/FoodLog"
  "$PROJECTS_ROOT/10_AI_OS/Anderson"
  "$PROJECTS_ROOT/90_ARCHIVE/Momentum"
  "$HOME/Code/ai-context"
  "$HOME/AIShared"
  "$HOME/.claude-full/shared-skills"
  "$PROJECTS_ROOT/50_CLIENTS/Nudge"
  "$HOME/Code/werkanders-os"
  "$HOME/Code/the-symbiotic-mind"
  "$HOME/Code/andersreality-website"
  "$HOME/Code/golden-soviet-gallery"
  "$HOME/Code/vlad-sterngold-os"
  "$HOME/Code/seo-ops"
  "$HOME/Code/public-github-fixes/prompt-translator"
  "$HOME/Code/public-github-fixes/notebooklm-skill"
)

exit_code=0
for repo in "${REPOS[@]}"; do
  if [[ ! -d "$repo" ]]; then
    echo "MISSING $repo"
    continue
  fi
  out="$(bash "$ASSEMBLE" --check "$repo" 2>&1)"; rc=$?
  case "$rc" in
    0) echo "PASS $repo" ;;
    1) echo "STALE $repo"; printf '%s\n' "$out" | sed 's/^/  /'; exit_code=1 ;;
    *) echo "ERROR $repo"; printf '%s\n' "$out" | sed 's/^/  /'; exit_code=1 ;;
  esac
done

exit "$exit_code"
