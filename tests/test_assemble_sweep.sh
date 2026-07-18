#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SWEEP="$ROOT/context-sync/assemble-sweep.sh"
ASSEMBLE="$ROOT/context-sync/assemble-agents.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_contains() {
  local haystack="$1" needle="$2"
  [[ "$haystack" == *"$needle"* ]] || fail "expected output to contain: $needle"
}

assert_not_contains() {
  local haystack="$1" needle="$2"
  [[ "$haystack" != *"$needle"* ]] || fail "expected output not to contain: $needle"
}

make_gitlink_index_entry() {
  local projects_root="$1" path="$2"
  local object_id="1111111111111111111111111111111111111111"

  git -C "$projects_root" init -q
  mkdir -p "$projects_root/$(dirname "$path")" "$projects_root/$path"
  git -C "$projects_root" update-index \
    --add --cacheinfo "160000,$object_id,$path"
}

make_gitlink_placeholder() {
  local projects_root="$1" path="$2"

  make_gitlink_index_entry "$projects_root" "$path"
  git -C "$projects_root" config -f .gitmodules submodule.fixture.path "$path"
  git -C "$projects_root" add .gitmodules
}

run_sweep() {
  local home="$1" projects_root="$2"
  set +e
  SWEEP_OUTPUT="$(HOME="$home" PROJECTS_ROOT="$projects_root" bash "$SWEEP" 2>&1)"
  SWEEP_RC=$?
  set -e
}

# An empty directory is informational only when the enclosing repository records
# that exact path as a gitlink. This models an uninitialized submodule checkout.
home="$TMP/placeholder/home"
projects_root="$TMP/placeholder/projects"
mkdir -p "$home" "$projects_root"
make_gitlink_placeholder "$projects_root" "20_PRODUCTS/FoodLog"

run_sweep "$home" "$projects_root"
[[ "$SWEEP_RC" == "0" ]] || fail "gitlink placeholder sweep exited $SWEEP_RC: $SWEEP_OUTPUT"
assert_contains "$SWEEP_OUTPUT" "MISSING $projects_root/20_PRODUCTS/FoodLog"
assert_not_contains "$SWEEP_OUTPUT" "ERROR $projects_root/20_PRODUCTS/FoodLog"

# Empty ordinary directories and non-empty malformed repositories must remain
# errors; valid and stale repositories retain their existing classifications.
home="$TMP/classification/home"
projects_root="$TMP/classification/projects"
mkdir -p \
  "$home" \
  "$projects_root/00_SYSTEM/anders-config" \
  "$projects_root/10_AI_OS/AndersMem" \
  "$projects_root/10_AI_OS/Anderson" \
  "$projects_root/90_ARCHIVE/Momentum" \
  "$home/Code/ai-context"

# A gitlink with only untracked .gitmodules metadata is malformed, not a
# verified uninitialized submodule. Both records must belong to the parent
# repository's index.
make_gitlink_index_entry "$projects_root" "10_AI_OS/AndersMem"
git -C "$projects_root" config -f .gitmodules \
  submodule.untracked-fixture.path "10_AI_OS/AndersMem"

printf '# fixture header\n' > "$projects_root/00_SYSTEM/anders-config/AGENTS.header.md"
bash "$ASSEMBLE" "$projects_root/00_SYSTEM/anders-config" >/dev/null

printf '# fixture header\n' > "$home/Code/ai-context/AGENTS.header.md"
bash "$ASSEMBLE" "$home/Code/ai-context" >/dev/null
printf '\nlocal drift\n' >> "$home/Code/ai-context/AGENTS.md"

printf 'not an assembled repository\n' > "$projects_root/90_ARCHIVE/Momentum/README.md"

run_sweep "$home" "$projects_root"
[[ "$SWEEP_RC" == "1" ]] || fail "mixed classification sweep exited $SWEEP_RC: $SWEEP_OUTPUT"
assert_contains "$SWEEP_OUTPUT" "PASS $projects_root/00_SYSTEM/anders-config"
assert_contains "$SWEEP_OUTPUT" "ERROR $projects_root/10_AI_OS/AndersMem"
assert_contains "$SWEEP_OUTPUT" "ERROR $projects_root/10_AI_OS/Anderson"
assert_contains "$SWEEP_OUTPUT" "ERROR $projects_root/90_ARCHIVE/Momentum"
assert_contains "$SWEEP_OUTPUT" "STALE $home/Code/ai-context"

printf 'assemble-sweep classification tests: OK\n'
