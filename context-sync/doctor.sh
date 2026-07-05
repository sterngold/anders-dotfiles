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
#   15  canonical AGENTS.md missing while workspace present, OR CLAUDE.md is not a
#       thin pointer (missing column-0 `@AGENTS.md` import) — thin-pointer model —
#       OR an AGENTS.md-canonical repo has drifted from agents-canon.md
#       (assemble-sweep.sh reports STALE/ERROR) — OR the primary checkout
#       (PROJECTS_ROOT) has drifted materially from origin/main
#   16  (reserved — was render-claude.sh error; unused under the thin-pointer model)
#   17  cc(1) project-resolver invariant breach — an active project does not resolve
#       uniquely via `cc <name>` (name collision or unreachable; see zsh/cc-doctor.zsh)
#
# Usage: bash doctor.sh           # human-readable bullets + summary (default)
#        bash doctor.sh --json    # machine-readable: {"exit_code":N,"findings":[…]}
#        make doctor
#
# --json contract: a single JSON object on stdout, no human bullets. Each finding
# is {id, code, status, summary} where id = section ("symlinks"/"imports"/…),
# status = "pass"|"fail", code = the 10–17 class (0 on pass). exit_code mirrors
# the human-mode exit. Dependency-free (no jq/python) so it runs on any host.

set -uo pipefail   # NOT -e: we want to run every check and aggregate.

JSON_MODE=0
for arg in "$@"; do
  case "$arg" in
    --json) JSON_MODE=1 ;;
    *) echo "doctor.sh: unknown argument: $arg" >&2; exit 2 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$SCRIPT_DIR/.." && pwd)"
HOME_DIR="${HOME}"
PROJECTS_ROOT="${PROJECTS_ROOT:-$HOME/Code/my-projects}"

ROUTER="$REPO/claude/CLAUDE.md"

# Committed context files to scan for leaked literals (token/~/$VAR only).
COMMITTED_CONTEXT=(
  "$REPO/context-sync/mcp.json.template"
  "$REPO/claude/CLAUDE.md"
)

# Managed home symlinks install.sh creates (skip ones not present on this host).
MANAGED_LINKS=(
  "$HOME_DIR/.claude-full/CLAUDE.md"
  "$HOME_DIR/.claude-full/statusline.sh"
  "$HOME_DIR/.claude-full/keybindings.json"
  "$HOME_DIR/.claude-full/skills"
  "$HOME_DIR/.claude-full/agents"
  "$HOME_DIR/.codex/AGENTS.md"
)

# Track the LOWEST failing-class code so the result matches the header's
# "first failing class in listed order" contract regardless of check order.
fail_code=0
# JSON-mode accumulation. SECTION is the id each finding carries; section()
# sets it (and prints the human header only outside --json).
findings=()
SECTION=""
json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"; s="${s//\"/\\\"}"
  s="${s//$'\t'/\\t}"; s="${s//$'\r'/\\r}"; s="${s//$'\n'/\\n}"
  printf '%s' "$s"
}
add_finding() {  # code status summary…
  local code="$1" status="$2"; shift 2
  findings+=("{\"id\":\"$(json_escape "$SECTION")\",\"code\":$code,\"status\":\"$status\",\"summary\":\"$(json_escape "$*")\"}")
}
section() { SECTION="$1"; (( JSON_MODE )) || echo "[$1]"; }
note_fail() {
  local code="$1"; shift
  if (( JSON_MODE )); then add_finding "$code" fail "$*"; else echo "  ✗ [$code] $*"; fi
  { [[ $fail_code -eq 0 ]] || (( code < fail_code )); } && fail_code="$code"
}
note_ok() {
  if (( JSON_MODE )); then add_finding 0 pass "$*"; else echo "  ✓ $*"; fi
}

(( JSON_MODE )) || echo "context doctor — host=$(uname -s) HOME=$HOME_DIR PROJECTS_ROOT=$PROJECTS_ROOT"

# --- 10: symlink health -----------------------------------------------------
section symlinks
for link in "${MANAGED_LINKS[@]}"; do
  if [[ -L "$link" ]]; then
    if [[ -e "$link" ]]; then note_ok "$link -> $(readlink "$link")"
    else note_fail 10 "broken symlink: $link -> $(readlink "$link") (target missing)"; fi
  fi
done

# --- 11 / 13: @import targets + vault presence ------------------------------
section imports
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
      ~/*)   target="$HOME_DIR/${imp#~/}" ;;
      "/"*)  target="$imp" ;;
      *)     target="$(dirname "$ROUTER")/$imp" ;;
    esac
    if [[ -e "$target" ]]; then
      note_ok "@$imp -> $target"
    else
      case "$imp" in
        ~/Vaults/*)
          if [[ -d "$HOME_DIR/Vaults" ]]; then
            note_fail 11 "missing import: @$imp"
          else
            note_fail 13 "vault import @$imp but ~/Vaults absent"
          fi
          ;;
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
section literals
leak_re='/Users/|/home/[^/]+/'
for f in "${COMMITTED_CONTEXT[@]}"; do
  [[ -e "$f" ]] || continue                 # not present on this host — nothing to scan
  if [[ ! -r "$f" ]]; then
    note_fail 12 "cannot read committed file (treat as suspect): $f"; continue
  fi
  # Branch on grep's THREE states: 0=found, 1=clean, >1=error. Folding error
  # into "clean" would let this safety check pass vacuously on an unreadable file.
  # 2>/dev/null keeps --json stdout-pure: an incidental grep diagnostic (binary
  # match, rc>=2) must NOT leak to stderr where a caller merging streams would
  # corrupt the JSON. The rc>=2 branch below still converts a real grep error
  # into a code-12 finding, so no information is lost.
  hits="$(grep -nE "$leak_re" "$f" 2>/dev/null)"; rc=$?
  case $rc in
    0) note_fail 12 "leaked absolute path in committed file: $f"; (( JSON_MODE )) || printf '%s\n' "$hits" | sed 's/^/      /' ;;
    1) note_ok "no leaked literals: ${f#"$REPO"/}" ;;
    *) note_fail 12 "grep errored (rc=$rc) scanning $f — cannot verify" ;;
  esac
done

# --- 14: rendered .mcp.json -------------------------------------------------
section mcp
if [[ -d "$PROJECTS_ROOT" ]]; then
  if [[ -f "$PROJECTS_ROOT/.mcp.json" ]]; then note_ok "rendered: $PROJECTS_ROOT/.mcp.json"
  else note_fail 14 "workspace present but $PROJECTS_ROOT/.mcp.json not rendered (run render-mcp.sh)"; fi
else
  note_ok "no workspace on this host ($PROJECTS_ROOT) — .mcp.json not required"
fi

# --- 15: canonical AGENTS.md + thin-pointer CLAUDE.md -----------------------
# Thin-pointer model (2026-05-31): AGENTS.md is the hand-edited canonical source;
# CLAUDE.md is a STATIC pointer that imports it via a column-0 `@AGENTS.md`.
# Nothing is generated → no render drift. We assert structural integrity instead:
#   - canonical AGENTS.md present (HARD FAIL if missing while workspace present —
#     GPT-5.5 guard 2026-05-31), and
#   - CLAUDE.md (if present) actually points to it via `@AGENTS.md`.
section agents
if [[ -d "$PROJECTS_ROOT" ]]; then
  if [[ ! -f "$PROJECTS_ROOT/AGENTS.md" ]]; then
    note_fail 15 "canonical AGENTS.md missing at $PROJECTS_ROOT (thin-pointer source absent)"
  elif [[ -f "$PROJECTS_ROOT/CLAUDE.md" ]] && ! grep -qE '^@AGENTS\.md' "$PROJECTS_ROOT/CLAUDE.md"; then
    note_fail 15 "CLAUDE.md is not a thin pointer — missing column-0 '@AGENTS.md' import"
  else
    note_ok "AGENTS.md canonical; CLAUDE.md points to it (@AGENTS.md)"
  fi
else
  note_ok "no workspace on this host — context check not required"
fi

# --- 15 (cont.): AGENTS.md-canon drift sweep --------------------------------
# assemble-sweep.sh (context-sync/) walks the fixed roster of AGENTS.md-canonical
# repos (AGENTS-CANON-STATUS.md "done" table) and reports PASS/STALE/ERROR/MISSING
# per repo, non-mutating. A STALE/ERROR repo means agents-canon.md moved but that
# repo's AGENTS.md was never re-assembled — same failure family as the check above
# (canonical-source drift), so it shares code 15. MISSING repos are informational
# only (this host doesn't have that checkout) and never fail the section.
SWEEP="$SCRIPT_DIR/assemble-sweep.sh"
if [[ -f "$SWEEP" ]]; then
  sweep_out="$(bash "$SWEEP" 2>&1)"; sweep_rc=$?
  drifted="$(printf '%s\n' "$sweep_out" | grep -E '^(STALE|ERROR) ' | sed -E 's/^(STALE|ERROR) //' || true)"
  if [[ "$sweep_rc" -ne 0 ]]; then
    if [[ -n "$drifted" ]]; then
      note_fail 15 "AGENTS.md canon drift — $(printf '%s' "$drifted" | paste -sd';' -) — run: bash $SWEEP"
    else
      note_fail 15 "assemble-sweep.sh exited $sweep_rc with no STALE/ERROR lines — inspect output"
    fi
    (( JSON_MODE )) || printf '%s\n' "$sweep_out" | sed 's/^/      /'
  else
    note_ok "AGENTS.md canon in sync across every present repo (assemble-sweep.sh)"
  fi
else
  note_fail 15 "assemble-sweep.sh missing at $SWEEP"
fi

# --- 15 (cont.): primary-checkout hygiene ------------------------------------
# The primary checkout (PROJECTS_ROOT) is contested shared state (git-minimal.md)
# — it should stay close to origin/main and reasonably clean. Drift here is a
# leading indicator of stranded/unpushed work or a session that never landed.
# Best-effort `fetch --quiet` with a short timeout when available; offline or a
# failed fetch is NOT a failure — skip silently, same convention as the cc-resolve
# check above skipping cleanly without zsh.
if [[ -d "$PROJECTS_ROOT/.git" ]]; then
  fetch_ok=1
  if command -v timeout >/dev/null 2>&1; then
    timeout 10 git -C "$PROJECTS_ROOT" fetch --quiet origin main >/dev/null 2>&1 || fetch_ok=0
  else
    git -C "$PROJECTS_ROOT" fetch --quiet origin main >/dev/null 2>&1 || fetch_ok=0
  fi
  if [[ "$fetch_ok" -eq 1 ]]; then
    behind="$(git -C "$PROJECTS_ROOT" rev-list --count HEAD..origin/main 2>/dev/null || echo 0)"
    dirty="$(git -C "$PROJECTS_ROOT" status --porcelain 2>/dev/null | grep -vc '^??' || true)"
    if [[ "$behind" -gt 3 || "$dirty" -gt 10 ]]; then
      note_fail 15 "primary checkout ($PROJECTS_ROOT) drifted — $behind commit(s) behind origin/main, $dirty dirty tracked file(s); back up first (stash: 'git stash push -u', or a backup branch — see rules/git-minimal.md) before any reset/checkout"
    else
      note_ok "primary checkout in sync ($behind behind origin/main, $dirty dirty tracked files)"
    fi
  else
    note_ok "primary-checkout drift check skipped (offline or fetch failed)"
  fi
else
  note_ok "no primary checkout .git at $PROJECTS_ROOT — hygiene check not required"
fi

# --- 17: cc(1) project-resolver invariants ----------------------------------
# Every active project must resolve uniquely via `cc <name>` (no collision, none
# unreachable). Born from a latent bug found only by accident — an archived project
# shadowed an active one of the same name, so `cc <name>` aborted "ambiguous". The
# check logic lives in zsh/cc-doctor.zsh (single source; also runnable standalone).
# It needs the live workspace + zsh; skips cleanly without either.
section cc-resolve
if [[ ! -d "$PROJECTS_ROOT" ]]; then
  note_ok "no workspace on this host — cc resolver check not required"
elif ! command -v zsh >/dev/null 2>&1; then
  note_ok "zsh unavailable — cc resolver check skipped"
elif [[ ! -f "$REPO/zsh/cc-doctor.zsh" ]]; then
  note_fail 17 "cc-doctor.zsh missing at $REPO/zsh/cc-doctor.zsh"
else
  cc_out="$(PROJECTS_ROOT="$PROJECTS_ROOT" zsh "$REPO/zsh/cc-doctor.zsh" 2>&1)"; cc_rc=$?
  case $cc_rc in
    0) note_ok "cc resolver: every active project resolves uniquely"
       (( JSON_MODE )) || printf '%s\n' "$cc_out" | sed 's/^/      /' ;;
    1) note_fail 17 "cc resolver INV-1 breach — an active project does not resolve cleanly"
       (( JSON_MODE )) || printf '%s\n' "$cc_out" | sed 's/^/      /' ;;
    *) note_fail 17 "cc resolver check harness error (rc=$cc_rc)"
       (( JSON_MODE )) || printf '%s\n' "$cc_out" | sed 's/^/      /' ;;
  esac
fi

if (( JSON_MODE )); then
  joined=""
  if (( ${#findings[@]} )); then IFS=,; joined="${findings[*]}"; unset IFS; fi
  printf '{"exit_code":%d,"findings":[%s]}\n' "$fail_code" "$joined"
else
  echo ""
  if [[ $fail_code -eq 0 ]]; then echo "doctor: all green ✓"; else echo "doctor: FAILED (exit $fail_code)"; fi
fi
exit "$fail_code"
