#!/usr/bin/env bash
# test_cc_worktree_parked_branch.sh — a session worktree left on the wrong branch.
#
# `_cc_ensure_worktree` reuses `.claude/worktrees/<name>` only while it sits on `wt/<name>`.
# Any other branch (or a detached HEAD) is refused with rc=75, and `_cc_launch` then allocates
# `<name>-2`. The refusal is right — reusing a worktree parked on `main` would put a session's
# commits on `main` — but the PARKED STATE IS PERMANENT. Nothing ever puts the worktree back,
# so every later `cc <name>` skips it and leaks another numbered successor.
#
# Observed 2026-08-02: a session finished a task in `.claude/worktrees/Nudge`, ran
# `git switch main`, and never switched back. `cc nudge` refused from then on. A sweep found
# seven more worktrees in the same state, one project already leaking its THIRD.
#
# The fix is the same shape the hollow-skeleton branch already uses: self-heal ONLY when the
# state is provably lossless — clean tree AND HEAD already contained in the base ref, so
# leaving the parked branch discards nothing. Everything else must still refuse.
#
# These tests drive the real zsh functions, not a reimplementation.

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ALIASES="$ROOT_DIR/zsh/cc-aliases.zsh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

[ -r "$ALIASES" ] || { echo "FAIL: $ALIASES not readable" >&2; exit 1; }
command -v zsh >/dev/null 2>&1 || { echo "SKIP: zsh not available" >&2; exit 0; }

fails=0
fail() { echo "FAIL: $*" >&2; fails=$((fails + 1)); }

# --- fixture: a real repo whose PRIMARY is detached, so `main` is free to be checked out -----
# (This mirrors the observed shape: a submodule primary sits detached at the parent's gitlink,
# so a session worktree can — and did — take `main` itself.)
REPO="$WORK/repo"
mkdir -p "$REPO/00_SYSTEM/Foo"
git -C "$REPO" init -q -b main
git -C "$REPO" config user.name "Test User"
git -C "$REPO" config user.email "test@example.com"
printf 'hello\n' > "$REPO/00_SYSTEM/Foo/README.md"
git -C "$REPO" add -A
git -C "$REPO" commit -qm "initial"
git -C "$REPO" checkout -q --detach

ensure() {
  local repo="$1" subpath="$2" name="$3"
  zsh -c '
    source "$1" >/dev/null 2>&1
    out=$(_cc_ensure_worktree "$2" "$3" "$4" 2>/tmp/cc_perr.$$)
    rc=$?
    printf "%s|%s\n" "$rc" "$out"
    cat /tmp/cc_perr.$$ >&2
    rm -f /tmp/cc_perr.$$
  ' _ "$ALIASES" "$repo" "$subpath" "$name"
}

branch_of() { git -C "$1" rev-parse --abbrev-ref HEAD 2>/dev/null; }

# Create the worktree normally, then park it on $2: "" = `main`, "detach" = detached HEAD at
# main, anything else = a new branch of that name. Verifies the park actually happened — git
# refuses `main` to a second worktree, and a fixture that fails silently tests nothing.
make_parked() {
  local name="$1" onto="$2" want
  ensure "$REPO" "" "$name" >/dev/null 2>&1
  local wt="$REPO/.claude/worktrees/$name"
  case "$onto" in
    "")       git -C "$wt" switch -q main 2>/dev/null;            want="main" ;;
    detach)   git -C "$wt" switch -q --detach main 2>/dev/null;   want="HEAD" ;;
    *)        git -C "$wt" switch -q -c "$onto" 2>/dev/null;      want="$onto" ;;
  esac
  [ "$(branch_of "$wt")" = "$want" ] \
    || fail "fixture: $name could not be parked on ${onto:-main} (it is on $(branch_of "$wt"))"
}

# --- case 1: parked on `main`, clean, nothing unique -> SELF-HEAL back to wt/<name> ----------
# The exact observed failure. Leaving `main` here discards nothing, so refusing forever (and
# leaking <name>-2) costs the user a worktree for no safety gain.
make_parked "Healme" ""
[ "$(branch_of "$REPO/.claude/worktrees/Healme")" = "main" ] \
  || fail "fixture: Healme was not parked on main"
out=$(ensure "$REPO" "" "Healme" 2>"$WORK/err1"); rc="${out%%|*}"; path="${out#*|}"
[ "$rc" = "0" ] \
  || fail "parked-on-main (clean, absorbed): expected self-heal rc=0, got rc=$rc ($(tr '\n' ' ' < "$WORK/err1"))"
[ "$(branch_of "$REPO/.claude/worktrees/Healme")" = "wt/Healme" ] \
  || fail "parked-on-main: expected branch wt/Healme, got $(branch_of "$REPO/.claude/worktrees/Healme")"
[ "$path" = "$REPO/.claude/worktrees/Healme" ] \
  || fail "parked-on-main: wrong path echoed: $path"
[ -f "$REPO/.claude/worktrees/Healme/00_SYSTEM/Foo/README.md" ] \
  || fail "parked-on-main: project files missing after self-heal"
grep -qi 'restor\|wt/Healme' "$WORK/err1" \
  || fail "parked-on-main: self-healed SILENTLY — a branch change must always be announced"

# --- case 2: parked HEAD carries commits NOT in base -> must still REFUSE -------------------
# Detached with its own commit: the eligible-shape check passes, so this reaches — and must be
# stopped by — the absorbed check. Nothing but HEAD references that commit.
ensure "$REPO" "" "Ahead" >/dev/null 2>&1
git -C "$REPO/.claude/worktrees/Ahead" checkout -q --detach
printf 'work\n' > "$REPO/.claude/worktrees/Ahead/NEW.md"
git -C "$REPO/.claude/worktrees/Ahead" add -A
git -C "$REPO/.claude/worktrees/Ahead" commit -qm "unpushed task work"
sha_before=$(git -C "$REPO/.claude/worktrees/Ahead" rev-parse HEAD)
out=$(ensure "$REPO" "" "Ahead" 2>"$WORK/err2"); rc="${out%%|*}"
[ "$rc" != "0" ] \
  || fail "parked with commits not in base: expected refusal, got rc=0 — the commit would be orphaned"
[ "$(git -C "$REPO/.claude/worktrees/Ahead" rev-parse HEAD)" = "$sha_before" ] \
  || fail "parked with commits not in base: HEAD moved off the only ref holding that commit"
[ -f "$REPO/.claude/worktrees/Ahead/NEW.md" ] \
  || fail "parked with commits not in base: committed file disappeared"

# --- case 3: parked on `main` with a DIRTY tree -> must still REFUSE ------------------------
make_parked "Dirty" ""
printf 'uncommitted edit\n' >> "$REPO/.claude/worktrees/Dirty/00_SYSTEM/Foo/README.md"
out=$(ensure "$REPO" "" "Dirty" 2>"$WORK/err3"); rc="${out%%|*}"
[ "$rc" != "0" ] \
  || fail "parked with dirty tree: expected refusal, got rc=0"
[ "$(branch_of "$REPO/.claude/worktrees/Dirty")" = "main" ] \
  || fail "parked with dirty tree: branch was changed anyway"
grep -q 'uncommitted edit' "$REPO/.claude/worktrees/Dirty/00_SYSTEM/Foo/README.md" \
  || fail "parked with dirty tree: uncommitted edit was destroyed"

# --- case 4: parked (detached) with an UNTRACKED file -> refuse (it may be session WIP) ------
make_parked "Untracked" "detach"
printf 'scratch\n' > "$REPO/.claude/worktrees/Untracked/SCRATCH.md"
out=$(ensure "$REPO" "" "Untracked" 2>"$WORK/err4"); rc="${out%%|*}"
[ "$rc" != "0" ] \
  || fail "parked with untracked file: expected refusal, got rc=0"
[ -f "$REPO/.claude/worktrees/Untracked/SCRATCH.md" ] \
  || fail "parked with untracked file: SCRATCH.md was destroyed"

# --- case 4b: clean AND absorbed, but on a NAMED branch -> still REFUSE ----------------------
# The narrowing that keeps the standing preservation promise (test_agent_worktree_freshness.sh):
# `main`/detached cannot be deliberate context, a named branch can. Losing nothing is not
# sufficient licence to move someone else's checkout.
make_parked "Named" "review/someones-context"
out=$(ensure "$REPO" "" "Named" 2>"$WORK/err4b"); rc="${out%%|*}"
[ "$rc" != "0" ] \
  || fail "parked on a named branch (clean, absorbed): expected refusal, got rc=0 — a review checkout would be moved"
[ "$(branch_of "$REPO/.claude/worktrees/Named")" = "review/someones-context" ] \
  || fail "parked on a named branch: the checkout was moved out from under its owner"

# --- case 5: DETACHED HEAD, clean, absorbed -> self-heal (same lossless shape as case 1) -----
ensure "$REPO" "" "Detached" >/dev/null 2>&1
git -C "$REPO/.claude/worktrees/Detached" checkout -q --detach
out=$(ensure "$REPO" "" "Detached" 2>"$WORK/err5"); rc="${out%%|*}"
[ "$rc" = "0" ] \
  || fail "parked detached (clean, absorbed): expected self-heal rc=0, got rc=$rc ($(tr '\n' ' ' < "$WORK/err5"))"
[ "$(branch_of "$REPO/.claude/worktrees/Detached")" = "wt/Detached" ] \
  || fail "parked detached: expected branch wt/Detached, got $(branch_of "$REPO/.claude/worktrees/Detached")"

# --- case 6: wt/<name> STILL EXISTS -> reattach to it, never recreate over its commits -------
ensure "$REPO" "" "Reattach" >/dev/null 2>&1
printf 'session work\n' > "$REPO/.claude/worktrees/Reattach/SESSION.md"
git -C "$REPO/.claude/worktrees/Reattach" add -A
git -C "$REPO/.claude/worktrees/Reattach" commit -qm "work on the session branch"
wt_sha=$(git -C "$REPO/.claude/worktrees/Reattach" rev-parse HEAD)
git -C "$REPO/.claude/worktrees/Reattach" switch -q --detach main   # park it, wt/Reattach survives
out=$(ensure "$REPO" "" "Reattach" 2>"$WORK/err6"); rc="${out%%|*}"
[ "$rc" = "0" ] \
  || fail "parked with surviving wt/ branch: expected reattach rc=0, got rc=$rc ($(tr '\n' ' ' < "$WORK/err6"))"
[ "$(branch_of "$REPO/.claude/worktrees/Reattach")" = "wt/Reattach" ] \
  || fail "parked with surviving wt/ branch: not reattached"
[ "$(git -C "$REPO/.claude/worktrees/Reattach" rev-parse HEAD)" = "$wt_sha" ] \
  || fail "parked with surviving wt/ branch: wt/Reattach was RECREATED over its commits"
[ -f "$REPO/.claude/worktrees/Reattach/SESSION.md" ] \
  || fail "parked with surviving wt/ branch: session commit content lost"

# --- case 7: healthy reuse is untouched (false direction) ------------------------------------
out=$(ensure "$REPO" "00_SYSTEM/Foo" "Healthy" 2>"$WORK/err7"); rc="${out%%|*}"
[ "$rc" = "0" ] || fail "healthy create: expected rc=0, got $rc"
out=$(ensure "$REPO" "00_SYSTEM/Foo" "Healthy" 2>"$WORK/err7b"); rc="${out%%|*}"; path="${out#*|}"
[ "$rc" = "0" ] || fail "healthy reuse: expected rc=0, got $rc ($(tr '\n' ' ' < "$WORK/err7b"))"
[ "$path" = "$REPO/.claude/worktrees/Healthy/00_SYSTEM/Foo" ] || fail "healthy reuse: wrong path: $path"
grep -qi 'restor' "$WORK/err7b" \
  && fail "healthy reuse: announced a restore it did not perform"

if [ "$fails" -ne 0 ]; then
  echo "cc parked-branch tests FAILED ($fails)" >&2
  exit 1
fi
echo "cc parked-branch tests passed"
