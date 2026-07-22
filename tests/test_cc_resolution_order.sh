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

if [ "$fails" -ne 0 ]; then
  echo "cc resolution-order tests FAILED ($fails)" >&2
  exit 1
fi
echo "cc resolution-order tests passed"
