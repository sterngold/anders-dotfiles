#!/usr/bin/env bash

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/github-transport-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

export HOME="$TMP/home"
mkdir -p "$HOME"

# Reproduce a host upgraded from the old HTTPS→SSH policy.
git config --global url."git@github.com:".insteadOf "https://github.com/"

bash "$REPO/context-sync/configure-github-transport.sh"

if git config --global --get-all url."git@github.com:".insteadOf >/dev/null 2>&1; then
  echo "legacy HTTPS→SSH rewrite still configured" >&2
  exit 1
fi

canonical="$(git config --global --get-all url."https://github.com/".insteadOf)"
[[ "$canonical" == "git@github.com:" ]] || {
  echo "canonical SSH→HTTPS rewrite missing" >&2
  exit 1
}

git init -q "$TMP/repo"
git -C "$TMP/repo" remote add origin git@github.com:sterngold/example.git
ssh_effective="$(git -C "$TMP/repo" ls-remote --get-url origin)"
[[ "$ssh_effective" == "https://github.com/sterngold/example.git" ]] || {
  echo "SSH remote did not resolve to HTTPS: $ssh_effective" >&2
  exit 1
}

git -C "$TMP/repo" remote set-url origin https://github.com/sterngold/example.git
https_effective="$(git -C "$TMP/repo" ls-remote --get-url origin)"
[[ "$https_effective" == "https://github.com/sterngold/example.git" ]] || {
  echo "HTTPS remote was rewritten away from HTTPS: $https_effective" >&2
  exit 1
}

echo "GitHub transport rewrite: OK"
