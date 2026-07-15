#!/usr/bin/env bash

# Keep GitHub transport HTTPS-canonical for Claude Code's domain-based sandbox.
# Remove the pre-policy reverse rewrite first; otherwise HTTPS remotes continue
# resolving to SSH even after the canonical SSH→HTTPS rule is added.

set -euo pipefail

git config --global --unset-all url."git@github.com:".insteadOf 2>/dev/null || true
git config --global url."https://github.com/".insteadOf "git@github.com:"

echo "git: GitHub transport is HTTPS-canonical (legacy reverse rewrite absent)"
