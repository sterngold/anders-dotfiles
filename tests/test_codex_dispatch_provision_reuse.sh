#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

mkdir -p "$TMPDIR/bin" "$TMPDIR/projects/Foo"
cat > "$TMPDIR/bin/codex" <<'SH'
#!/usr/bin/env bash
exit 0
SH
chmod +x "$TMPDIR/bin/codex"

# npm stub: records every invocation (cwd + args) to a log file so tests can assert
# whether/where it ran, without a real network call or a real npm install.
NPM_LOG="$TMPDIR/npm-invocations.log"
: > "$NPM_LOG"
cat > "$TMPDIR/bin/npm" <<SH
#!/usr/bin/env bash
echo "\$(pwd)|\$*" >> "$NPM_LOG"
exit 0
SH
chmod +x "$TMPDIR/bin/npm"

export PATH="$TMPDIR/bin:$PATH"
export PROJECTS_ROOT="$TMPDIR/projects"

git -C "$PROJECTS_ROOT" init -q
git -C "$PROJECTS_ROOT" config user.name "Test User"
git -C "$PROJECTS_ROOT" config user.email "test@example.com"
printf 'committed\n' > "$PROJECTS_ROOT/Foo/README.md"
# package-lock.json committed at the REPO ROOT (not Foo/): codex_root defaults to the
# worktree root (the whole repo checkout, since no --cwd is passed in these tests), so
# the provisioning check needs the lockfile to live there too.
printf '{}\n' > "$PROJECTS_ROOT/package-lock.json"
git -C "$PROJECTS_ROOT" add Foo/README.md package-lock.json
git -C "$PROJECTS_ROOT" commit -qm "initial"

BRIEF="$TMPDIR/brief.md"
printf 'Do the build.\n' > "$BRIEF"
export ROOT_DIR BRIEF NPM_LOG

CONTAINER="$PROJECTS_ROOT/.codex/worktrees/Foo"
OUT="$TMPDIR/out.txt"
ERR="$TMPDIR/err.txt"

pass=0
fail=0
check() {
  local desc="$1" rc="$2"
  if [[ "$rc" -eq 0 ]]; then
    echo "OK: $desc"
    pass=$((pass + 1))
  else
    echo "FAIL: $desc" >&2
    echo "--- stderr ---" >&2
    cat "$ERR" >&2
    fail=$((fail + 1))
  fi
}

# Remove any existing container, leaving repo_root clean.
reset_container() {
  if [[ -d "$CONTAINER" ]]; then
    git -C "$PROJECTS_ROOT" worktree remove --force "$CONTAINER" 2>/dev/null || rm -rf "$CONTAINER"
  fi
  git -C "$PROJECTS_ROOT" worktree prune 2>/dev/null || true
}

# Create a stale container directly with `git worktree add` (independent of the function
# under test), on the given branch, optionally leaving it dirty.
setup_stale_container() {
  local branch="$1" dirty="${2:-0}"
  reset_container
  mkdir -p "$PROJECTS_ROOT/.codex/worktrees"
  git -C "$PROJECTS_ROOT" worktree add -q -b "$branch" "$CONTAINER" HEAD
  if [[ "$dirty" -eq 1 ]]; then
    printf 'dirty\n' > "$CONTAINER/dirty.txt"
  fi
}

# ============================================================================
# Test 1: reuse + CLEAN stale container -> auto-heals onto the requested branch
# ============================================================================
setup_stale_container "stale-clean" 0
set +e
zsh -f <<'ZSH' >"$OUT" 2>"$ERR"
source "$ROOT_DIR/zsh/codex-dispatch.zsh"
_cc_resolve_project() { print -r -- "$1/Foo"; }
_cc_worktree_base() { git -C "$1" rev-parse HEAD; }
codex-dispatch --skip-deps --reuse --branch healed-clean Foo "$BRIEF"
ZSH
rc=$?
set -e

t1_ok=0
[[ "$rc" -eq 0 ]] || t1_ok=1
grep -q "auto-healed stale container: was on 'stale-clean', now 'healed-clean'" "$ERR" || t1_ok=1
final_branch="$(git -C "$CONTAINER" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
[[ "$final_branch" == "healed-clean" ]] || t1_ok=1
check "reuse + clean stale container auto-heals to the requested branch" "$t1_ok"

# ============================================================================
# Test 1b: heal must PRESERVE an existing requested branch's tip (PR #47 P1) —
# switching to a pre-existing branch with prior build commits must not reset it.
# ============================================================================
setup_stale_container "stale-clean-2" 0
# Pre-create the requested branch with one extra commit beyond base.
git -C "$CONTAINER" switch -q -c keep-my-tip
printf 'prior build work\n' > "$CONTAINER/built.txt"
git -C "$CONTAINER" add built.txt
git -C "$CONTAINER" -c user.name=t -c user.email=t@t -c commit.gpgsign=false commit -qm "prior build commit"
TIP_BEFORE="$(git -C "$CONTAINER" rev-parse keep-my-tip)"
git -C "$CONTAINER" switch -q stale-clean-2   # container back on the stale branch
export TIP_BEFORE
set +e
zsh -f <<'ZSH' >"$OUT" 2>"$ERR"
source "$ROOT_DIR/zsh/codex-dispatch.zsh"
_cc_resolve_project() { print -r -- "$1/Foo"; }
_cc_worktree_base() { git -C "$1" rev-parse HEAD; }
codex-dispatch --skip-deps --reuse --branch keep-my-tip Foo "$BRIEF"
ZSH
rc=$?
set -e
t1b_ok=0
[[ "$rc" -eq 0 ]] || t1b_ok=1
final_branch="$(git -C "$CONTAINER" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
[[ "$final_branch" == "keep-my-tip" ]] || t1b_ok=1
TIP_AFTER="$(git -C "$CONTAINER" rev-parse keep-my-tip)"
[[ "$TIP_AFTER" == "$TIP_BEFORE" ]] || t1b_ok=1
check "heal preserves an existing requested branch's tip (no reset to base)" "$t1b_ok"

# ============================================================================
# Test 2: reuse + DIRTY stale container -> refuses, names the remedy, nothing lost
# ============================================================================
setup_stale_container "stale-dirty" 1
set +e
zsh -f <<'ZSH' >"$OUT" 2>"$ERR"
source "$ROOT_DIR/zsh/codex-dispatch.zsh"
_cc_resolve_project() { print -r -- "$1/Foo"; }
_cc_worktree_base() { git -C "$1" rev-parse HEAD; }
codex-dispatch --skip-deps --reuse --branch healed-dirty Foo "$BRIEF"
ZSH
rc=$?
set -e

t2_ok=0
[[ "$rc" -ne 0 ]] || t2_ok=1
grep -q "reuse refused" "$ERR" || t2_ok=1
grep -q "worktree remove" "$ERR" || t2_ok=1
grep -q "commit/stash" "$ERR" || t2_ok=1
still_branch="$(git -C "$CONTAINER" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
[[ "$still_branch" == "stale-dirty" ]] || t2_ok=1
[[ -f "$CONTAINER/dirty.txt" ]] || t2_ok=1
check "reuse + dirty stale container refuses and names the remedy, nothing lost" "$t2_ok"

# ============================================================================
# Test 3: provisioning fires for real (non-dry) on a fresh worktree
# ============================================================================
reset_container
: > "$NPM_LOG"
set +e
zsh -f <<'ZSH' >"$OUT" 2>"$ERR"
source "$ROOT_DIR/zsh/codex-dispatch.zsh"
_cc_resolve_project() { print -r -- "$1/Foo"; }
_cc_worktree_base() { git -C "$1" rev-parse HEAD; }
codex-dispatch --branch build-1 Foo "$BRIEF"
ZSH
rc=$?
set -e

t3_ok=0
[[ "$rc" -eq 0 ]] || t3_ok=1
grep -qF "$CONTAINER|ci --no-audit --no-fund" "$NPM_LOG" || t3_ok=1
check "provisioning: npm ci invoked in the worktree root when lockfile present + node_modules missing" "$t3_ok"

# ============================================================================
# Test 4: --skip-deps -> no npm invocation at all
# ============================================================================
reset_container
: > "$NPM_LOG"
set +e
zsh -f <<'ZSH' >"$OUT" 2>"$ERR"
source "$ROOT_DIR/zsh/codex-dispatch.zsh"
_cc_resolve_project() { print -r -- "$1/Foo"; }
_cc_worktree_base() { git -C "$1" rev-parse HEAD; }
codex-dispatch --skip-deps --branch build-2 Foo "$BRIEF"
ZSH
rc=$?
set -e

t4_ok=0
[[ "$rc" -eq 0 ]] || t4_ok=1
[[ ! -s "$NPM_LOG" ]] || t4_ok=1
[[ ! -d "$CONTAINER/node_modules" ]] || t4_ok=1
check "--skip-deps skips dependency provisioning entirely" "$t4_ok"

# ============================================================================
# Test 5: --dry-run prints the would-run line and leaves node_modules absent
# ============================================================================
reset_container
: > "$NPM_LOG"
set +e
zsh -f <<'ZSH' >"$OUT" 2>"$ERR"
source "$ROOT_DIR/zsh/codex-dispatch.zsh"
_cc_resolve_project() { print -r -- "$1/Foo"; }
_cc_worktree_base() { git -C "$1" rev-parse HEAD; }
codex-dispatch --dry-run --branch build-3 Foo "$BRIEF"
ZSH
rc=$?
set -e

t5_ok=0
[[ "$rc" -eq 0 ]] || t5_ok=1
grep -qF "would run: npm ci" "$ERR" || t5_ok=1
[[ ! -s "$NPM_LOG" ]] || t5_ok=1
[[ ! -d "$CONTAINER/node_modules" ]] || t5_ok=1
check "--dry-run prints would-run npm ci and does not actually provision" "$t5_ok"

# ============================================================================
# Bonus test 6: python markers present, no venv -> warns. Exercises the python leg of
# the same new provisioning block; not one of the 5 required cases but cheap to cover
# since the code path is new.
# ============================================================================
reset_container
: > "$NPM_LOG"
printf '[project]\nname = "x"\n' > "$PROJECTS_ROOT/pyproject.toml"
git -C "$PROJECTS_ROOT" add pyproject.toml
git -C "$PROJECTS_ROOT" commit -qm "add pyproject"
set +e
zsh -f <<'ZSH' >"$OUT" 2>"$ERR"
source "$ROOT_DIR/zsh/codex-dispatch.zsh"
_cc_resolve_project() { print -r -- "$1/Foo"; }
_cc_worktree_base() { git -C "$1" rev-parse HEAD; }
codex-dispatch --branch build-4 Foo "$BRIEF"
ZSH
rc=$?
set -e

t6_ok=0
[[ "$rc" -eq 0 ]] || t6_ok=1
grep -q "no venv in fresh worktree" "$ERR" || t6_ok=1
check "python markers with no venv print the warn-only line (bonus coverage)" "$t6_ok"

echo ""
echo "codex-dispatch provision/reuse tests: $pass passed, $fail failed"
[[ "$fail" -eq 0 ]]
