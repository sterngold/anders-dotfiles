#!/usr/bin/env bash
# test_cc_resolution_order.sh — AND-1923. A workspace-relative name is not a cwd path.
#
# `_cc_resolve_project` tried the bare cwd-relative branch BEFORE `$root/$name`. Since a
# worktree of the workspace contains the same tree as the workspace, running the DOCUMENTED
# invocation `cc 20_PRODUCTS/Nudge` from inside `.claude/worktrees/<x>/` resolved to the copy
# under the CWD. `_cc_launch` then still classified that path as living under $PROJECTS_ROOT
# and derived a subpath like `.claude/worktrees/<x>/20_PRODUCTS/Nudge`, so `_cc_ensure_worktree`
# built `.claude/worktrees/<name>/.claude/worktrees/<x>/20_PRODUCTS/Nudge` — a directory tree
# that gets CREATED but never becomes a registered worktree.
#
# That is the hollow skeleton AND-1921 documents. #65 made a hollow path safe to encounter;
# this closes the path that manufactures one. Reported by Codex on #19 and unanswered until
# 2026-07-22, because the mandatory review-thread sweep omits this repo.
#
# Both directions matter: `cc ./x` and `cc ../y` MUST stay cwd-relative — the prefix is how the
# caller names the intent — so a fix that simply makes everything workspace-relative is wrong.

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ALIASES="$ROOT_DIR/zsh/cc-aliases.zsh"
# Physical path: on macOS /var is a symlink to /private/var, and zsh's ${name:A} resolves
# symlinks. Comparing a resolved result against an unresolved expectation fails on the link,
# not on the behaviour — a test red for the wrong reason proves nothing.
WORK="$(cd "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$WORK"' EXIT

[ -r "$ALIASES" ] || { echo "FAIL: $ALIASES not readable" >&2; exit 1; }
command -v zsh >/dev/null 2>&1 || { echo "SKIP: zsh not available" >&2; exit 0; }

fails=0
fail() { echo "FAIL: $*" >&2; fails=$((fails + 1)); }

# --- fixture -------------------------------------------------------------------------------
# A workspace with a real project, plus a worktree-shaped copy of the same tree beneath it.
WS="$WORK/ws"
mkdir -p "$WS/20_PRODUCTS/Nudge"
mkdir -p "$WS/.claude/worktrees/Other/20_PRODUCTS/Nudge"   # the shadowing copy
mkdir -p "$WORK/elsewhere/sibling"

# Resolve a name from a given cwd. Echoes the resolved path (stdout of the real zsh function).
resolve() { # <cwd> <name>
  zsh -c '
    source "$1" >/dev/null 2>&1
    cd "$2" || exit 9
    _cc_resolve_project "$3" "$4" 2>/dev/null
  ' _ "$ALIASES" "$1" "$WS" "$2"
}

# --- case 1: THE REGRESSION — workspace-relative wins over the cwd shadow -------------------
got=$(resolve "$WS/.claude/worktrees/Other" "20_PRODUCTS/Nudge")
[ "$got" = "$WS/20_PRODUCTS/Nudge" ] \
  || fail "workspace-relative from inside a worktree: expected $WS/20_PRODUCTS/Nudge, got '${got:-<empty>}'"

# The specific signature of the bug: resolving to the copy under .claude/worktrees/.
case "$got" in
  */.claude/worktrees/*) fail "resolved INTO a worktree copy ('$got') — this is the hollow-skeleton path" ;;
esac

# --- case 2: same name from an unrelated cwd still resolves workspace-relative --------------
got=$(resolve "$WORK/elsewhere" "20_PRODUCTS/Nudge")
[ "$got" = "$WS/20_PRODUCTS/Nudge" ] \
  || fail "workspace-relative from an unrelated cwd: expected $WS/20_PRODUCTS/Nudge, got '${got:-<empty>}'"

# --- case 3 (FALSE DIRECTION): ./x stays cwd-relative ---------------------------------------
# Do not "fix" this by making every name workspace-relative.
got=$(resolve "$WORK/elsewhere" "./sibling")
[ "$got" = "$WORK/elsewhere/sibling" ] \
  || fail "./sibling must stay cwd-relative: expected $WORK/elsewhere/sibling, got '${got:-<empty>}'"

# --- case 4 (FALSE DIRECTION): ../x stays cwd-relative --------------------------------------
got=$(resolve "$WORK/elsewhere/sibling" "../sibling")
[ "$got" = "$WORK/elsewhere/sibling" ] \
  || fail "../sibling must stay cwd-relative: expected $WORK/elsewhere/sibling, got '${got:-<empty>}'"

# --- case 5 (FALSE DIRECTION): an absolute path is unchanged --------------------------------
got=$(resolve "$WS" "$WORK/elsewhere/sibling")
[ "$got" = "$WORK/elsewhere/sibling" ] \
  || fail "absolute path must be used as-is: expected $WORK/elsewhere/sibling, got '${got:-<empty>}'"

# --- case 6 (FALSE DIRECTION): a bare relative dir that exists ONLY under cwd still works ----
# `cc some/dir` where some/dir is not in the workspace must still fall back to the cwd copy.
mkdir -p "$WORK/elsewhere/only/here"
got=$(resolve "$WORK/elsewhere" "only/here")
[ "$got" = "$WORK/elsewhere/only/here" ] \
  || fail "cwd-only relative dir must still resolve: expected $WORK/elsewhere/only/here, got '${got:-<empty>}'"

# --- case 7: _cc_ensure_worktree refuses a subpath that points back into a worktree ----------
# Belt and braces: no legitimate project lives inside another worktree's tree, so even if some
# future resolution path produces one, the tree must not be created. Assert the DIRECTORY is
# absent, not merely that the exit code was non-zero — the defect's signature is a tree on disk.
REPO="$WORK/repo"
mkdir -p "$REPO/20_PRODUCTS/Nudge"
git -C "$REPO" init -q -b main
git -C "$REPO" config user.name t; git -C "$REPO" config user.email t@e.com
printf 'x\n' > "$REPO/20_PRODUCTS/Nudge/README.md"
git -C "$REPO" add -A && git -C "$REPO" commit -qm init

BAD_SUB=".claude/worktrees/Other/20_PRODUCTS/Nudge"
rc=$(zsh -c '
  source "$1" >/dev/null 2>&1
  _cc_ensure_worktree "$2" "$3" "Victim" >/dev/null 2>&1
  echo $?
' _ "$ALIASES" "$REPO" "$BAD_SUB")
[ "$rc" != "0" ] || fail "nested-worktree subpath: expected refusal, got rc=0"
[ ! -d "$REPO/.claude/worktrees/Victim/.claude" ] \
  || fail "nested-worktree subpath: a nested tree was CREATED at $REPO/.claude/worktrees/Victim/.claude"
# AND-1923 P2(b): the would-be worktree root itself must not exist either — if the refusal ever
# regresses into a fallthrough, `_cc_ensure_worktree`'s "absent" branch would happily `git
# worktree add` a REAL worktree at this path (no manual nested mkdir required to fail this).
[ ! -e "$REPO/.claude/worktrees/Victim" ] \
  || fail "nested-worktree subpath: the would-be worktree dir $REPO/.claude/worktrees/Victim was CREATED"

# --- fixture for cases 8-9: a REAL registered worktree of $REPO, named "Foo" ----------------
# AND-1923 P2(b): case 7 above proves the genuinely-nested refusal. These two prove the other
# face — an explicit path that IS (or sits inside) an already-registered worktree must open in
# place instead of being caught by the same .claude/worktrees/* pattern.
git -C "$REPO" worktree add -q -b wt/Foo "$REPO/.claude/worktrees/Foo" main >/dev/null 2>&1 \
  || fail "fixture setup: could not register worktree Foo"

# Same "<rc>|<stdout>" harness as test_cc_worktree_integrity.sh, so stdout and stderr don't mix.
# AND-1923 review Finding 3 (P3): the mktemp'd stderr file used to be deleted UNREAD — on a
# failing case the refusal diagnostic (the one thing that says WHY) was thrown away, and an
# empty $5 from a failed mktemp would have fed `2>""` to the inner zsh call and misattributed
# whatever that produced to the callee. Guard the mktemp result and stash the stderr text in
# $_ensure_err (a global, read by callers after each `ensure` call) instead of discarding it —
# stdout contract ("<rc>|<path>") is unchanged so every existing caller keeps working as-is.
ensure() { # <repo> <subpath> <name> [<force_new>]
  local err result
  _ensure_err=""
  err=$(mktemp) || { _ensure_err="ensure(): mktemp failed"; printf '99|\n'; return; }
  result=$(zsh -c '
    source "$1" >/dev/null 2>&1
    out=$(_cc_ensure_worktree "$2" "$3" "$4" "$5" 2>"$6")
    printf "%s|%s\n" "$?" "$out"
  ' _ "$ALIASES" "$1" "$2" "$3" "${4:-0}" "$err")
  _ensure_err=$(tr '\n' ' ' < "$err" 2>/dev/null)
  rm -f "$err"
  printf '%s\n' "$result"
}

# --- case 8: explicit path AT a registered worktree's own root — open in place ---------------
out=$(ensure "$REPO" ".claude/worktrees/Foo" "Foo"); rc="${out%%|*}"; path="${out#*|}"
[ "$rc" = "0" ] \
  || fail "registered worktree (direct): expected rc=0, got $rc (stderr: ${_ensure_err:-<empty>})"
[ "$path" = "$REPO/.claude/worktrees/Foo" ] \
  || fail "registered worktree (direct): expected open-in-place path $REPO/.claude/worktrees/Foo, got '${path:-<empty>}' (stderr: ${_ensure_err:-<empty>})"
# No SECOND worktree/branch must have been fabricated for this call.
git -C "$REPO" worktree list --porcelain | grep -q "^worktree .*/Foo$" \
  || fail "registered worktree (direct): Foo is no longer a registered worktree after the call"
[ "$(git -C "$REPO" worktree list --porcelain | grep -c '^worktree ')" = "2" ] \
  || fail "registered worktree (direct): worktree count changed — a new one was created"

# --- case 9: explicit path INSIDE a registered worktree — open in place, no refusal ----------
mkdir -p "$REPO/.claude/worktrees/Foo/20_PRODUCTS/Nudge"
out=$(ensure "$REPO" ".claude/worktrees/Foo/20_PRODUCTS/Nudge" "Nudge"); rc="${out%%|*}"; path="${out#*|}"
[ "$rc" = "0" ] \
  || fail "registered worktree (nested): expected rc=0, got $rc (stderr: ${_ensure_err:-<empty>})"
[ "$path" = "$REPO/.claude/worktrees/Foo/20_PRODUCTS/Nudge" ] \
  || fail "registered worktree (nested): expected open-in-place path, got '${path:-<empty>}' (stderr: ${_ensure_err:-<empty>})"
[ "$(git -C "$REPO" worktree list --porcelain | grep -c '^worktree ')" = "2" ] \
  || fail "registered worktree (nested): worktree count changed — a new one was created"

# --- case 10: NESTED worktree-inside-worktree — the first .claude/worktrees/<seg> occurrence -
# is registered, but the path this branch would open is the SECOND, never-classified one. This
# is exactly the hollow-skeleton shape AND-1921 exists to refuse. AND-1923 review Finding 1(a).
git -C "$REPO" worktree add -q -b wt/A "$REPO/.claude/worktrees/A" main >/dev/null 2>&1 \
  || fail "fixture setup: could not register worktree A"
NESTED_SUB=".claude/worktrees/A/.claude/worktrees/B"
out=$(ensure "$REPO" "$NESTED_SUB" "Victim2"); rc="${out%%|*}"; path="${out#*|}"
[ "$rc" != "0" ] \
  || fail "nested worktree-in-worktree: expected refusal, got rc=0 path='$path'"
[ ! -e "$REPO/.claude/worktrees/A/.claude/worktrees" ] \
  || fail "nested worktree-in-worktree: a nested tree was CREATED at $REPO/.claude/worktrees/A/.claude/worktrees"
[ ! -e "$REPO/.claude/worktrees/Victim2" ] \
  || fail "nested worktree-in-worktree: the would-be worktree dir Victim2 was CREATED"

# --- case 11: PREFIX before the container — the registered segment is a DIFFERENT directory ---
# than the one this branch would open. `A/.claude/worktrees/B`: seg=B classifies the TOP-LEVEL
# `.claude/worktrees/B` (registered below), but the path opened would be the unrelated, never-
# validated `A/.claude/worktrees/B`. AND-1923 review Finding 1(b).
mkdir -p "$REPO/A/.claude/worktrees/B"
printf 'unrelated\n' > "$REPO/A/.claude/worktrees/B/UNVALIDATED.txt"
git -C "$REPO" worktree add -q -b wt/B "$REPO/.claude/worktrees/B" main >/dev/null 2>&1 \
  || fail "fixture setup: could not register worktree B"
PREFIXED_SUB="A/.claude/worktrees/B"
out=$(ensure "$REPO" "$PREFIXED_SUB" "Victim3"); rc="${out%%|*}"; path="${out#*|}"
[ "$rc" != "0" ] \
  || fail "prefix-before-container: expected refusal, got rc=0 path='$path' — opened an unclassified directory"
[ ! -e "$REPO/.claude/worktrees/Victim3" ] \
  || fail "prefix-before-container: the would-be worktree dir Victim3 was CREATED"
[ "$(git -C "$REPO" worktree list --porcelain | grep -c '^worktree ')" = "4" ] \
  || fail "prefix-before-container: worktree count changed unexpectedly (fixture has Foo, A, B + main)"

# --- case 12: `--new` against an explicit path naming a registered worktree must refuse -------
# AND-1923 review Finding 2 (P2). --new asks for a FRESH, uniquely-named worktree; an explicit
# path that IS ALREADY a registered worktree is a direct conflict. Exercises _cc_launch (not
# just the unit under it), because the defect is in how force_new REACHES _cc_ensure_worktree.
REPO_PHYS="$(cd "$REPO" && pwd -P)"
out12=$(CC_NO_WORKTREE='' PROJECTS_ROOT="$REPO_PHYS" zsh -c '
  source "$1" >/dev/null 2>&1
  # Never let a regressed/mutated guard shell out to the REAL claude binary — shadow it with a
  # stub. A refusal must happen before this is ever reached, so seeing the stub fire is itself
  # a failure signature, not just an inert safety net.
  claude() { printf "STUB_CLAUDE_INVOKED\n" >&2; return 42; }
  _cc_launch CC /nonexistent-config-dir 0 0 0 local "$2" --new
  printf "RC=%s\n" "$?"
' _ "$ALIASES" "$REPO_PHYS/.claude/worktrees/Foo" 2>"$WORK/err12")
rc12="${out12##*RC=}"
[ "$rc12" = "1" ] \
  || fail "--new vs registered worktree path: expected refusal rc=1, got '${rc12:-<empty>}' (stderr: $(tr '\n' ' ' < "$WORK/err12"))"
grep -qi 'new' "$WORK/err12" \
  || fail "--new vs registered worktree path: refused but stderr doesn't name the conflict: $(tr '\n' ' ' < "$WORK/err12")"
grep -q "STUB_CLAUDE_INVOKED" "$WORK/err12" \
  && fail "--new vs registered worktree path: claude was reached — the guard let a live launch through"
[ ! -e "$REPO_PHYS/.claude/worktrees/Foo-2" ] \
  || fail "--new vs registered worktree path: a Foo-2 directory was fabricated"
if git -C "$REPO_PHYS" show-ref --verify --quiet refs/heads/wt/Foo-2; then
  fail "--new vs registered worktree path: a wt/Foo-2 branch was fabricated"
fi
[ "$(git -C "$REPO_PHYS" worktree list --porcelain | grep -c '^worktree ')" = "4" ] \
  || fail "--new vs registered worktree path: worktree count changed (shared worktree touched or a new one created)"

# --- fixture for cases 13-14: a SIBLING repo (NOT under PROJECTS_ROOT) with its own
# registered worktree "Foo" -------------------------------------------------------------------
# Codex P2 on #70: `cc /path/to/sibling/.claude/worktrees/Foo` resolves via Rule 0 (an existing
# absolute dir). _cc_launch's sibling-repo branch then derives repo_root by asking git for the
# TARGET's own toplevel — but a linked worktree's toplevel IS itself, so repo_root becomes the
# worktree, not the repo the AND-1923 P2(b) registered-worktree check (cases 8-12 above) needs to
# see. subpath comes out empty, the check never fires, and _cc_ensure_worktree tries to grow a
# NESTED worktree inside the one already checked out on wt/Foo — which git refuses ("already
# used by worktree at ...") after mkdir-ing a nested .claude/worktrees/ skeleton first.
ROOT13="$WORK/root13"
mkdir -p "$ROOT13"
SIB="$WORK/sibling-repo"
mkdir -p "$SIB/proj"
git -C "$SIB" init -q -b main
git -C "$SIB" config user.name t; git -C "$SIB" config user.email t@e.com
printf 'x\n' > "$SIB/proj/README.md"
git -C "$SIB" add -A && git -C "$SIB" commit -qm init
git -C "$SIB" worktree add -q -b wt/Foo "$SIB/.claude/worktrees/Foo" main >/dev/null 2>&1 \
  || fail "fixture setup: could not register sibling worktree Foo"
SIB_PHYS="$(cd "$SIB" && pwd -P)"

# --- case 13: explicit path to a SIBLING repo's registered worktree — opens in place ----------
out13=$(CC_NO_WORKTREE='' PROJECTS_ROOT="$ROOT13" zsh -c '
  source "$1" >/dev/null 2>&1
  claude() { printf "STUB_CLAUDE_INVOKED %s\n" "$PWD" >&2; return 0; }
  _cc_launch CC /nonexistent-config-dir 0 0 0 local "$2"
  printf "RC=%s\n" "$?"
' _ "$ALIASES" "$SIB_PHYS/.claude/worktrees/Foo" 2>"$WORK/err13")
rc13="${out13##*RC=}"
[ "$rc13" = "0" ] \
  || fail "sibling registered worktree (direct): expected rc=0, got '${rc13:-<empty>}' (stderr: $(tr '\n' ' ' < "$WORK/err13"))"
grep -q "STUB_CLAUDE_INVOKED $SIB_PHYS/.claude/worktrees/Foo" "$WORK/err13" \
  || fail "sibling registered worktree (direct): claude was not launched IN PLACE at $SIB_PHYS/.claude/worktrees/Foo (stderr: $(tr '\n' ' ' < "$WORK/err13"))"
[ "$(git -C "$SIB_PHYS" worktree list --porcelain | grep -c '^worktree ')" = "2" ] \
  || fail "sibling registered worktree (direct): worktree count changed in the sibling repo — a new one was created"
[ ! -e "$SIB_PHYS/.claude/worktrees/Foo/.claude/worktrees" ] \
  || fail "sibling registered worktree (direct): a NESTED .claude/worktrees skeleton was created inside Foo"

# --- case 14: `--new` against an explicit path into a SIBLING repo's registered worktree ------
# Same conflict as case 12, exercised through the sibling-repo branch instead of the
# under-$PROJECTS_ROOT branch — proves _cc_launch feeds the existing --new refusal the correct
# (corrected-to-primary) repo_root/subpath rather than bypassing it via the wrong repo_root.
out14=$(CC_NO_WORKTREE='' PROJECTS_ROOT="$ROOT13" zsh -c '
  source "$1" >/dev/null 2>&1
  claude() { printf "STUB_CLAUDE_INVOKED\n" >&2; return 42; }
  _cc_launch CC /nonexistent-config-dir 0 0 0 local "$2" --new
  printf "RC=%s\n" "$?"
' _ "$ALIASES" "$SIB_PHYS/.claude/worktrees/Foo" 2>"$WORK/err14")
rc14="${out14##*RC=}"
[ "$rc14" = "1" ] \
  || fail "sibling --new vs registered worktree path: expected refusal rc=1, got '${rc14:-<empty>}' (stderr: $(tr '\n' ' ' < "$WORK/err14"))"
grep -qi 'new' "$WORK/err14" \
  || fail "sibling --new vs registered worktree path: refused but stderr doesn't name the conflict: $(tr '\n' ' ' < "$WORK/err14")"
grep -q "STUB_CLAUDE_INVOKED" "$WORK/err14" \
  && fail "sibling --new vs registered worktree path: claude was reached — the guard let a live launch through"
[ ! -e "$SIB_PHYS/.claude/worktrees/Foo-2" ] \
  || fail "sibling --new vs registered worktree path: a Foo-2 directory was fabricated"
if git -C "$SIB_PHYS" show-ref --verify --quiet refs/heads/wt/Foo-2; then
  fail "sibling --new vs registered worktree path: a wt/Foo-2 branch was fabricated"
fi
[ "$(git -C "$SIB_PHYS" worktree list --porcelain | grep -c '^worktree ')" = "2" ] \
  || fail "sibling --new vs registered worktree path: worktree count changed (shared worktree touched or a new one created)"

if [ "$fails" -ne 0 ]; then
  echo "cc resolution-order tests FAILED ($fails)" >&2
  exit 1
fi
echo "cc resolution-order tests passed"
