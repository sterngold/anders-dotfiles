#!/usr/bin/env bash
# test_cc_worktree_integrity.sh — a directory is not a worktree.
#
# `_cc_ensure_worktree` decided reuse-vs-create with a bare `[[ ! -d "$wt_root" ]]`. A path
# that exists but is NOT a registered git worktree therefore took the REUSE branch, and cc
# handed the session a directory with no `.git` anywhere beneath it. Git then walks UP past
# `.claude/worktrees/` and resolves every command to the PRIMARY checkout — the one the house
# rule designates read/view-only for landings.
#
# It is silent by construction: `git rev-parse --abbrev-ref HEAD` answers `main`, `git status`
# answers normally, and `_cc_ff_or_warn`'s own BROKEN-git-dir guard passes, because
# `rev-parse --git-dir` SUCCEEDS — it just succeeds about the wrong repo. The guard written to
# catch a broken worktree cannot see this one.
#
# Observed 2026-07-22: a session believing it was isolated ran `git checkout -b` against the
# primary while a concurrent actor held uncommitted work there.
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

# --- fixture: a real repo with one committed project ---------------------------------------
REPO="$WORK/repo"
mkdir -p "$REPO/00_SYSTEM/Foo"
git -C "$REPO" init -q -b main
git -C "$REPO" config user.name "Test User"
git -C "$REPO" config user.email "test@example.com"
printf 'hello\n' > "$REPO/00_SYSTEM/Foo/README.md"
git -C "$REPO" add -A
git -C "$REPO" commit -qm "initial"

# Drive the real function under zsh. Echoes: "<rc>|<stdout>" then stderr on fd 2.
ensure() {
  local repo="$1" subpath="$2" name="$3"
  zsh -c '
    source "$1" >/dev/null 2>&1
    out=$(_cc_ensure_worktree "$2" "$3" "$4" 2>/tmp/cc_err.$$)
    rc=$?
    printf "%s|%s\n" "$rc" "$out"
    cat /tmp/cc_err.$$ >&2
    rm -f /tmp/cc_err.$$
  ' _ "$ALIASES" "$repo" "$subpath" "$name"
}

# --- case 1: HOLLOW dir (exists, not a worktree) must NOT be handed back as a worktree ------
# This is the regression. It must either be repaired into a real worktree, or refused loudly.
mkdir -p "$REPO/.claude/worktrees/Hollow/00_SYSTEM/Foo"
out=$(ensure "$REPO" "00_SYSTEM/Foo" "Hollow" 2>"$WORK/err1"); rc="${out%%|*}"; path="${out#*|}"
if [ "$rc" = "0" ]; then
  # Accepted -> it must now be a REAL registered worktree with its own .git
  if [ ! -e "$REPO/.claude/worktrees/Hollow/.git" ]; then
    fail "hollow dir: returned success but $REPO/.claude/worktrees/Hollow has no .git (session would drive the PRIMARY)"
  fi
  if ! git -C "$REPO" worktree list --porcelain | grep -q "^worktree .*/Hollow$"; then
    fail "hollow dir: returned success but the path is not a registered worktree"
  fi
else
  grep -qi 'not a worktree\|hollow\|refus' "$WORK/err1" \
    || fail "hollow dir: refused (rc=$rc) but stderr does not say why: $(tr '\n' ' ' < "$WORK/err1")"
fi

# --- case 2: hollow dir HOLDING A FILE must never be silently destroyed ---------------------
mkdir -p "$REPO/.claude/worktrees/HasData"
printf 'precious\n' > "$REPO/.claude/worktrees/HasData/UNSAVED.txt"
out=$(ensure "$REPO" "" "HasData" 2>"$WORK/err2"); rc="${out%%|*}"
[ -f "$REPO/.claude/worktrees/HasData/UNSAVED.txt" ] \
  || fail "hollow dir with a file: UNSAVED.txt was destroyed — a non-worktree dir with content must never be removed"
[ "$rc" != "0" ] \
  || fail "hollow dir with a file: expected refusal (non-zero), got rc=0"

# --- case 2b: a FOREIGN repo parked at the path must be refused, never reused or removed ----
# The other face of the same class (Codex P2 on #65): an independent clone at
# .claude/worktrees/<project> DOES have toplevel == wt_root, so a toplevel-only check calls it
# a worktree and cc would refresh and launch the wrong repo. Membership is the object store.
FOREIGN="$REPO/.claude/worktrees/Foreign"
mkdir -p "$FOREIGN"
git -C "$FOREIGN" init -q -b main
git -C "$FOREIGN" config user.name "Other"
git -C "$FOREIGN" config user.email "other@example.com"
printf 'not ours\n' > "$FOREIGN/OTHER.md"
git -C "$FOREIGN" add -A
git -C "$FOREIGN" commit -qm "foreign repo"
out=$(ensure "$REPO" "" "Foreign" 2>"$WORK/err2b"); rc="${out%%|*}"
[ "$rc" != "0" ] || fail "foreign repo: expected refusal (non-zero), got rc=0 — cc would launch an unrelated repo"
grep -qi 'not a worktree of\|refus' "$WORK/err2b" \
  || fail "foreign repo: refused but stderr does not say why: $(tr '\n' ' ' < "$WORK/err2b")"
[ -f "$FOREIGN/OTHER.md" ] || fail "foreign repo: content was destroyed — a real repo must never be removed"
[ -d "$FOREIGN/.git" ] || fail "foreign repo: .git was destroyed"

# --- case 3: happy path, no dir -> a REAL worktree is created (false direction) -------------
out=$(ensure "$REPO" "00_SYSTEM/Foo" "Fresh" 2>"$WORK/err3"); rc="${out%%|*}"; path="${out#*|}"
[ "$rc" = "0" ] || fail "fresh worktree: expected rc=0, got $rc ($(tr '\n' ' ' < "$WORK/err3"))"
[ -e "$REPO/.claude/worktrees/Fresh/.git" ] || fail "fresh worktree: no .git created"
[ -f "$REPO/.claude/worktrees/Fresh/00_SYSTEM/Foo/README.md" ] || fail "fresh worktree: project files missing"
[ "$path" = "$REPO/.claude/worktrees/Fresh/00_SYSTEM/Foo" ] || fail "fresh worktree: wrong path echoed: $path"

# --- case 4: happy path, REUSE of a genuine worktree still works (false direction) ----------
out=$(ensure "$REPO" "00_SYSTEM/Foo" "Fresh" 2>"$WORK/err4"); rc="${out%%|*}"; path="${out#*|}"
[ "$rc" = "0" ] || fail "reuse: expected rc=0, got $rc ($(tr '\n' ' ' < "$WORK/err4"))"
[ -e "$REPO/.claude/worktrees/Fresh/.git" ] || fail "reuse: .git disappeared"
[ "$path" = "$REPO/.claude/worktrees/Fresh/00_SYSTEM/Foo" ] || fail "reuse: wrong path echoed: $path"

if [ "$fails" -ne 0 ]; then
  echo "cc worktree integrity tests FAILED ($fails)" >&2
  exit 1
fi
echo "cc worktree integrity tests passed"
