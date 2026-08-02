#!/usr/bin/env bash
# Regression coverage for reusable agent worktrees that have both local commits and
# new remote commits. Neither launcher may run an agent in that stale checkout.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

command -v zsh >/dev/null 2>&1 || { echo "SKIP: zsh not available"; exit 0; }

REMOTE="$WORK/remote.git"
REPO="$WORK/Repo"
ADVANCE="$WORK/advance"
PROJECTS_ROOT="$WORK/projects"
CLAUDE_LOG="$WORK/claude.log"
CODEX_LOG="$WORK/codex.log"
BRIEF="$WORK/brief.md"

mkdir -p "$REPO" "$PROJECTS_ROOT"
git -C "$REPO" init -q -b main
git -C "$REPO" config user.name "Test User"
git -C "$REPO" config user.email "test@example.com"
printf 'initial\n' > "$REPO/README.md"
git -C "$REPO" add README.md
git -C "$REPO" commit -qm "initial"
git clone -q --bare "$REPO" "$REMOTE"
git -C "$REPO" remote add origin "$REMOTE"
git -C "$REPO" fetch -q origin
git -C "$REPO" branch --set-upstream-to=origin/main main >/dev/null
printf '**/.claude/worktrees/\n**/.codex/worktrees/\n' >> "$REPO/.git/info/exclude"
git clone -q "$REMOTE" "$ADVANCE"
git -C "$ADVANCE" config user.name "Remote User"
git -C "$ADVANCE" config user.email "remote@example.com"
printf 'Do the build.\n' > "$BRIEF"

advance_remote() {
  local marker="$1"
  printf '%s\n' "$marker" >> "$ADVANCE/README.md"
  git -C "$ADVANCE" add README.md
  git -C "$ADVANCE" commit -qm "$marker"
  git -C "$ADVANCE" push -q origin main
}

make_task_commit() {
  local worktree="$1" marker="$2"
  printf '%s\n' "$marker" > "$worktree/$marker.txt"
  git -C "$worktree" add "$marker.txt"
  git -C "$worktree" -c user.name="Task User" -c user.email="task@example.com" \
    -c commit.gpgsign=false commit -qm "$marker"
}

# Claude Code: plain `cc Repo` is allowed to choose a fresh numbered worktree.
CLAUDE_WT="$REPO/.claude/worktrees/Repo"
mkdir -p "$REPO/.claude/worktrees"
git -C "$REPO" worktree add -q -b wt/Repo "$CLAUDE_WT" origin/main
make_task_commit "$CLAUDE_WT" claude-local
CLAUDE_TIP_BEFORE="$(git -C "$CLAUDE_WT" rev-parse HEAD)"
advance_remote remote-after-claude

export ROOT_DIR PROJECTS_ROOT REPO CLAUDE_LOG
set +e
zsh -f <<'ZSH' >"$WORK/claude.out" 2>"$WORK/claude.err"
source "$ROOT_DIR/zsh/cc-aliases.zsh"
_cc_resolve_project() { print -r -- "$REPO"; }
claude() { print -r -- "$PWD" > "$CLAUDE_LOG"; return 0; }
_cc_launch CC /nonexistent-config-dir 0 0 0 local Repo
ZSH
claude_rc=$?
set -e

[[ "$claude_rc" -eq 0 ]] || {
  echo "FAIL: Claude Code did not recover with a fresh worktree" >&2
  cat "$WORK/claude.err" >&2
  exit 1
}
CLAUDE_EXPECTED="$(cd "$REPO/.claude/worktrees/Repo-2" && pwd -P)"
[[ "$(<"$CLAUDE_LOG")" == "$CLAUDE_EXPECTED" ]] || {
  echo "FAIL: Claude Code launched in $(<"$CLAUDE_LOG"), not the fresh Repo-2 worktree" >&2
  cat "$WORK/claude.err" >&2
  exit 1
}
[[ "$(git -C "$CLAUDE_WT" rev-parse HEAD)" == "$CLAUDE_TIP_BEFORE" ]] \
  || { echo "FAIL: Claude Code changed the preserved divergent tip" >&2; exit 1; }
[[ "$(git -C "$REPO/.claude/worktrees/Repo-2" rev-parse --abbrev-ref HEAD)" == "wt/Repo-2" ]] \
  || { echo "FAIL: Claude Code fresh worktree is not on wt/Repo-2" >&2; exit 1; }
git -C "$REPO/.claude/worktrees/Repo-2" merge-base --is-ancestor origin/main HEAD \
  || { echo "FAIL: Claude Code fresh worktree is not based on origin/main" >&2; exit 1; }
echo "OK: Claude Code preserves divergence and launches a fresh origin/main worktree"

# The preserved default remains divergent. A later plain launch must reuse the healthy
# successor instead of leaking Repo-3, Repo-4, ... on every invocation.
: > "$CLAUDE_LOG"
set +e
zsh -f <<'ZSH' >"$WORK/claude-second.out" 2>"$WORK/claude-second.err"
source "$ROOT_DIR/zsh/cc-aliases.zsh"
_cc_resolve_project() { print -r -- "$REPO"; }
claude() { print -r -- "$PWD" > "$CLAUDE_LOG"; return 0; }
_cc_launch CC /nonexistent-config-dir 0 0 0 local Repo
ZSH
claude_second_rc=$?
set -e
[[ "$claude_second_rc" -eq 0 ]] || { echo "FAIL: second Claude Code launch failed" >&2; exit 1; }
[[ "$(<"$CLAUDE_LOG")" == "$CLAUDE_EXPECTED" ]] \
  || { echo "FAIL: second Claude Code launch did not reuse healthy Repo-2" >&2; exit 1; }
[[ ! -e "$REPO/.claude/worktrees/Repo-3" ]] \
  || { echo "FAIL: second Claude Code launch leaked an unnecessary Repo-3 worktree" >&2; exit 1; }
echo "OK: Claude Code reuses the healthy numbered successor on later plain launches"

# A registered path can also be on the wrong branch (observed live: `main` at the
# `wt/Nudge` path). That branch is preserved too, but the replacement must fetch before
# branching so a stale local origin/main cache cannot masquerade as a fresh worktree.
WRONG_REPO="$WORK/Wrong"
WRONG_LOG="$WORK/wrong-claude.log"
git clone -q "$REMOTE" "$WRONG_REPO"
git -C "$WRONG_REPO" config user.name "Wrong Branch User"
git -C "$WRONG_REPO" config user.email "wrong@example.com"
printf '**/.claude/worktrees/\n' >> "$WRONG_REPO/.git/info/exclude"
mkdir -p "$WRONG_REPO/.claude/worktrees"
git -C "$WRONG_REPO" worktree add -q -b unexpected-branch \
  "$WRONG_REPO/.claude/worktrees/Wrong" origin/main
WRONG_TIP_BEFORE="$(git -C "$WRONG_REPO/.claude/worktrees/Wrong" rev-parse HEAD)"
advance_remote remote-after-wrong-branch
REMOTE_TIP="$(git -C "$ADVANCE" rev-parse HEAD)"
export WRONG_REPO WRONG_LOG

zsh -f <<'ZSH' >"$WORK/wrong.out" 2>"$WORK/wrong.err"
source "$ROOT_DIR/zsh/cc-aliases.zsh"
_cc_resolve_project() { print -r -- "$WRONG_REPO"; }
claude() { print -r -- "$PWD" > "$WRONG_LOG"; return 0; }
_cc_launch CC /nonexistent-config-dir 0 0 0 local Wrong
ZSH

[[ "$(git -C "$WRONG_REPO/.claude/worktrees/Wrong" rev-parse HEAD)" == "$WRONG_TIP_BEFORE" ]] \
  || { echo "FAIL: Claude Code changed the wrong-branch worktree it promised to preserve" >&2; exit 1; }
[[ "$(git -C "$WRONG_REPO/.claude/worktrees/Wrong-2" rev-parse HEAD)" == "$REMOTE_TIP" ]] \
  || { echo "FAIL: wrong-branch recovery used stale cached origin/main instead of the live remote tip" >&2; cat "$WORK/wrong.err" >&2; exit 1; }
echo "OK: Claude Code wrong-branch recovery fetches before creating the successor"

# Codex: the requested branch is part of the dispatch contract, so silent renaming is
# unsafe. Reuse must fail closed before invoking Codex and leave the divergent tip intact.
CODEX_WT="$REPO/.codex/worktrees/Repo"
mkdir -p "$REPO/.codex/worktrees"
git -C "$REPO" worktree add -q -b wt/Repo-build "$CODEX_WT" origin/main
make_task_commit "$CODEX_WT" codex-local
CODEX_TIP_BEFORE="$(git -C "$CODEX_WT" rev-parse HEAD)"
advance_remote remote-after-codex

mkdir -p "$WORK/bin"
cat > "$WORK/bin/codex" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$PWD" > "$CODEX_LOG"
exit 0
SH
chmod +x "$WORK/bin/codex"
export PATH="$WORK/bin:$PATH" CODEX_LOG BRIEF

set +e
zsh -f <<'ZSH' >"$WORK/codex.out" 2>"$WORK/codex.err"
source "$ROOT_DIR/zsh/cc-aliases.zsh"
source "$ROOT_DIR/zsh/codex-dispatch.zsh"
_cc_resolve_project() { print -r -- "$REPO"; }
codex-dispatch --skip-deps --reuse --branch wt/Repo-build Repo "$BRIEF"
ZSH
codex_rc=$?
set -e

[[ "$codex_rc" -ne 0 ]] \
  || { echo "FAIL: Codex dispatch accepted a divergent reused worktree" >&2; exit 1; }
[[ ! -e "$CODEX_LOG" ]] \
  || { echo "FAIL: Codex was invoked in a divergent reused worktree" >&2; exit 1; }
[[ "$(git -C "$CODEX_WT" rev-parse HEAD)" == "$CODEX_TIP_BEFORE" ]] \
  || { echo "FAIL: Codex dispatch changed the preserved divergent tip" >&2; exit 1; }
grep -qi 'divergent.*preserved\|preserv.*divergent' "$WORK/codex.err" \
  || { echo "FAIL: Codex refusal does not explain that divergent work is preserved" >&2; cat "$WORK/codex.err" >&2; exit 1; }
grep -q 'origin/main' "$WORK/codex.err" \
  || { echo "FAIL: Codex refusal does not name the current base" >&2; cat "$WORK/codex.err" >&2; exit 1; }
echo "OK: Codex preserves divergence and refuses to launch on the stale branch"
