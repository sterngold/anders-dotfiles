#!/usr/bin/env zsh
# cc-doctor.zsh — assert the cc(1) project-resolver invariants over the LIVE workspace.
#
# WHY THIS EXISTS
#   A latent resolver bug — an archived project shadowing an active one of the same
#   name, so `cc <name>` aborted "ambiguous" — survived unnoticed until a typo made
#   us look. The 20-line collision sweep that found it is now a standing check.
#   Habit worth keeping: every one-off diagnostic that proves a property is a
#   standing check you haven't written yet.
#
# INVARIANTS
#   INV-1 (HARD)  Every ACTIVE project name resolves with exit 0 — no "no project
#                 named", no "ambiguous". Catches name collisions (cross-category or
#                 vs a ~/Code sibling) and unreachable projects. This is the exact
#                 class that bit alf-podcast.
#   NOTE  (soft)  Active names with a case-insensitive twin under 90_ARCHIVE. The
#                 resolver tolerates these now (archives aren't scanned), but the
#                 shadow is a structural smell — surfaced, never silent, so a future
#                 re-activation can't quietly reintroduce the ambiguity.
#
# The active-category set and the resolver come from the LIVE cc-aliases.zsh — this
# doctor holds no second copy of "what counts as a project".
#
# EXIT  0 all green (incl. NOTE-only) · 1 INV-1 breach · 3 harness/setup error.
# USAGE  zsh cc-doctor.zsh        # PROJECTS_ROOT honored; defaults to ~/Code/my-projects
#        CC_ALIASES_FILE=... zsh cc-doctor.zsh   # override the resolver source

emulate -L zsh                # standard opts → glob qualifiers on regardless of caller
set -u

ROOT="${PROJECTS_ROOT:-$HOME/Code/my-projects}"
ALIASES="${CC_ALIASES_FILE:-${0:A:h}/cc-aliases.zsh}"

if [[ ! -d "$ROOT" ]]; then
  print -r -- "cc-doctor: SKIP — no workspace at $ROOT (nothing to check on this host)"
  exit 0
fi
[[ -f "$ALIASES" ]] || { print -ru2 -- "cc-doctor: setup error — cc-aliases.zsh not found at $ALIASES"; exit 3; }
source "$ALIASES"
(( $+functions[_cc_resolve_project] )) || { print -ru2 -- "cc-doctor: setup error — _cc_resolve_project undefined after sourcing $ALIASES"; exit 3; }
(( ${#_CC_CATEGORIES} ))               || { print -ru2 -- "cc-doctor: setup error — _CC_CATEGORIES empty"; exit 3; }

# _cc_resolve_project reads a bare $CC_PROJECT_ROOTS (interactive shells run without
# nounset, so it's fine there). Define it (empty → resolver uses its default root) so
# our `set -u` doesn't abort inside the resolver — and so that abort can't be swallowed
# by the call's own >/dev/null 2>&1 redirect, the way it bit this script's first draft.
: "${CC_PROJECT_ROOTS:=}"

# ---- Build the ACTIVE project universe straight from the resolver's own inputs ----
typeset -aU active=()
typeset cat dir sroot
for cat in "${_CC_CATEGORIES[@]}"; do
  [[ -d "$ROOT/$cat" ]] || continue
  for dir in "$ROOT/$cat"/*(N/); do active+=("${dir:t}"); done
done
# Non-category direct children (skip every NN_* category prefix, incl. 90_ARCHIVE).
for dir in "$ROOT"/*(N/); do
  [[ "${dir:t}" == [0-9][0-9]_* ]] && continue
  active+=("${dir:t}")
done
# Rule-4 search roots (default: parent of $ROOT = ~/Code), mirroring the resolver.
typeset -a roots
if [[ -n "${CC_PROJECT_ROOTS:-}" ]]; then roots=("${(@s/:/)CC_PROJECT_ROOTS}"); else roots=("${ROOT:h}"); fi
for sroot in "${roots[@]}"; do
  [[ -d "$sroot" && "$sroot" != "$ROOT" ]] || continue
  for dir in "$sroot"/*(N/); do
    [[ "$dir" == "$ROOT" || "${dir:t}" == *-worktrees ]] && continue
    active+=("${dir:t}")
  done
done

# ---- INV-1: every active project resolves uniquely ----
typeset -a broken=()
typeset n why
for n in "${active[@]}"; do
  if ! _cc_resolve_project "$ROOT" "$n" >/dev/null 2>&1; then
    why="$(_cc_resolve_project "$ROOT" "$n" 2>&1 | head -1)"
    broken+=("$n — ${why#cc: }")
  fi
done

# ---- NOTE: active names with an archived twin (case-insensitive) ----
typeset -A arch_set=()
if [[ -d "$ROOT/90_ARCHIVE" ]]; then
  for dir in "$ROOT/90_ARCHIVE"/*(N/); do arch_set[${(L)${dir:t}}]=1; done
fi
typeset -a twins=()
for n in "${active[@]}"; do
  (( ${+arch_set[${(L)n}]} )) && twins+=("$n")   # ${+...} membership — nounset-safe
done

# ---- Report ----
print -r -- "cc-doctor: ${#active} active projects checked (root=$ROOT)"
(( ${#twins} )) && print -r -- "  NOTE archived twin(s) — active name also under 90_ARCHIVE: ${twins[*]}"
if (( ${#broken} )); then
  print -r -- "  ✗ INV-1 breach — these active projects do NOT resolve cleanly via cc:"
  for n in "${broken[@]}"; do print -r -- "      $n"; done
  exit 1
fi
print -r -- "  ✓ INV-1 every active project resolves uniquely"
exit 0
