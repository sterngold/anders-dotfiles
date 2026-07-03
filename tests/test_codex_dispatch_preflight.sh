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

export PATH="$TMPDIR/bin:$PATH"
export PROJECTS_ROOT="$TMPDIR/projects"

git -C "$PROJECTS_ROOT" init -q
git -C "$PROJECTS_ROOT" config user.name "Test User"
git -C "$PROJECTS_ROOT" config user.email "test@example.com"
printf 'committed\n' > "$PROJECTS_ROOT/Foo/README.md"
git -C "$PROJECTS_ROOT" add Foo/README.md
git -C "$PROJECTS_ROOT" commit -qm "initial"

BRIEF="$TMPDIR/brief.md"
printf 'Do the build.\n' > "$BRIEF"
export ROOT_DIR BRIEF

# This is the class AND-1680 protects against: the brief can be authored against a dirty
# primary checkout, but the isolated Codex worktree is created from committed state only.
printf 'not committed\n' > "$PROJECTS_ROOT/Foo/uncommitted.txt"

OUT="$TMPDIR/out.txt"
ERR="$TMPDIR/err.txt"
set +e
zsh -f <<'ZSH' >"$OUT" 2>"$ERR"
source "$ROOT_DIR/zsh/codex-dispatch.zsh"
_cc_resolve_project() { print -r -- "$1/Foo"; }
_cc_worktree_base() { git -C "$1" rev-parse HEAD; }
codex-dispatch --dry-run Foo "$BRIEF"
ZSH
rc=$?
set -e

if [[ "$rc" -eq 0 ]]; then
  echo "expected dirty-source preflight to refuse dispatch" >&2
  exit 1
fi
grep -q "source checkout has uncommitted changes" "$ERR"
grep -q -- "--allow-dirty-source" "$ERR"

zsh -f <<'ZSH' >"$OUT" 2>"$ERR"
source "$ROOT_DIR/zsh/codex-dispatch.zsh"
_cc_resolve_project() { print -r -- "$1/Foo"; }
_cc_worktree_base() { git -C "$1" rev-parse HEAD; }
codex-dispatch --dry-run --allow-dirty-source Foo "$BRIEF"
ZSH

grep -q "DRY RUN" "$ERR"
echo "OK: codex-dispatch dirty-source preflight"
