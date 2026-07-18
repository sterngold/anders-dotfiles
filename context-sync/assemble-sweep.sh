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

# An uninitialized submodule can leave an existing but empty directory at its
# roster path. Treat it like an absent checkout only when Git verifies that the
# exact empty path is a gitlink in its enclosing repository. Empty ordinary
# directories and non-empty broken checkouts must continue through --check and
# report ERROR rather than being hidden as MISSING.
is_uninitialized_submodule_placeholder() {
  local repo="$1"
  local repo_abs parent super rel entry record mode recorded_path
  local submodule_paths key path declared=0

  repo_abs="$(cd "$repo" 2>/dev/null && pwd -P)" || return 1
  entry="$(find "$repo_abs" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" || return 1
  [[ -z "$entry" ]] || return 1

  parent="$(dirname "$repo_abs")"
  super="$(git -C "$parent" rev-parse --show-toplevel 2>/dev/null)" || return 1
  case "$repo_abs" in
    "$super"/*) rel="${repo_abs#"$super"/}" ;;
    *) return 1 ;;
  esac

  record="$(git -C "$super" ls-files --stage -- "$rel" 2>/dev/null)" || return 1
  [[ -n "$record" && "$record" != *$'\n'* ]] || return 1
  mode="${record%% *}"
  recorded_path="${record#*$'\t'}"
  [[ "$mode" == "160000" && "$recorded_path" == "$rel" ]] || return 1

  submodule_paths="$(git -C "$super" config --blob :.gitmodules \
    --get-regexp '^submodule\..*\.path$' 2>/dev/null)" || return 1
  while IFS=' ' read -r key path; do
    if [[ -n "$key" && "$path" == "$rel" ]]; then
      declared=1
      break
    fi
  done <<< "$submodule_paths"
  [[ "$declared" == "1" ]]
}

exit_code=0
for repo in "${REPOS[@]}"; do
  if [[ ! -e "$repo" && ! -L "$repo" ]]; then
    echo "MISSING $repo"
    continue
  fi
  if [[ -L "$repo" || ! -d "$repo" ]]; then
    echo "ERROR $repo"
    echo "  assemble-sweep: roster path is a symlink or non-directory"
    exit_code=1
    continue
  fi
  if is_uninitialized_submodule_placeholder "$repo"; then
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
