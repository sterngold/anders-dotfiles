#!/usr/bin/env bash
# assemble-agents.sh — assemble a repo's AGENTS.md from two hand-edited sources:
#   1. <repo>/AGENTS.header.md          — per-repo header (§1–2: identity + build/test/lint)
#   2. context-sync/agents-canon.md     — shared canon (§3–13), ONE source for all repos
#
# AGENTS.md is the ASSEMBLED artifact (canonical for Codex/Cursor/etc. — flat inline text,
# no references). CLAUDE.md stays a STATIC thin pointer (`@AGENTS.md`) — this script never
# touches it. Centralizing §3–13 in agents-canon.md kills the 3-copy template drift (D4):
# edit the canon once, re-assemble, every repo's AGENTS.md updates identically.
#
# Usage:
#   bash assemble-agents.sh <repo-dir>            # write <repo-dir>/AGENTS.md if stale (idempotent)
#   bash assemble-agents.sh --check <repo-dir>    # 0=in sync · 1=stale/missing · 2=error; writes nothing
#
# Mirrors render-agents.sh's --check 0/1/2 contract so doctor.sh wiring stays uniform.
# No-ops are errors here (unlike render-agents.sh's no-workspace skip): if you point it at a
# repo, that repo is expected to have an AGENTS.header.md. Callers that iterate repos should
# skip repos without a header BEFORE calling, not rely on a silent exit 0.

set -euo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CANON="$SELF_DIR/agents-canon.md"
MARKER='@@AGENTS_HEADER@@'

# ---- arg parse -------------------------------------------------------------
CHECK=0
if [[ "${1:-}" == "--check" ]]; then CHECK=1; shift; fi
REPO="${1:-}"
if [[ -z "$REPO" ]]; then
  echo "assemble-agents: usage: assemble-agents.sh [--check] <repo-dir>" >&2; exit 2
fi
REPO="${REPO%/}"
HEADER="$REPO/AGENTS.header.md"
OUT="$REPO/AGENTS.md"

# ---- source validation (all failures = exit 2) ----------------------------
if [[ ! -f "$CANON" ]]; then
  echo "assemble-agents: ERROR — canon not found at $CANON" >&2; exit 2
fi
if [[ ! -f "$HEADER" ]]; then
  echo "assemble-agents: ERROR — no AGENTS.header.md in $REPO (write the §1–2 header first)" >&2; exit 2
fi
marker_count="$(grep -cxF "$MARKER" "$CANON" || true)"
if [[ "$marker_count" != "1" ]]; then
  echo "assemble-agents: ERROR — canon must contain the marker line '$MARKER' exactly once (found $marker_count)" >&2; exit 2
fi

# ---- assemble: replace the marker line with the header file verbatim -------
assemble() {
  awk -v hdr="$HEADER" -v marker="$MARKER" '
    $0 == marker {
      while ((getline line < hdr) > 0) print line
      close(hdr)
      next
    }
    { print }
  ' "$CANON"
}

# ---- --check: 0 in sync · 1 stale/missing · 2 error ------------------------
if [[ "$CHECK" == "1" ]]; then
  if [[ ! -f "$OUT" ]]; then
    echo "assemble-agents: $OUT missing — run: bash assemble-agents.sh $REPO" >&2; exit 1
  fi
  assembled="$(assemble)" || { echo "assemble-agents: ERROR — assembly failed (unreadable source?)" >&2; exit 2; }
  current="$(cat "$OUT")"  || { echo "assemble-agents: ERROR — cannot read $OUT" >&2; exit 2; }
  if [[ "$assembled" == "$current" ]]; then exit 0; fi
  echo "assemble-agents: $OUT is STALE vs AGENTS.header.md + agents-canon.md — run: bash assemble-agents.sh $REPO" >&2
  exit 1
fi

# ---- write (idempotent) ----------------------------------------------------
if [[ -f "$OUT" ]] && diff <(assemble) "$OUT" >/dev/null 2>&1; then
  echo "assemble-agents: $OUT already current — no change"
  exit 0
fi
tmp="$(mktemp "${OUT}.XXXXXX")"
trap 'rm -f "$tmp"' EXIT
assemble > "$tmp"
chmod 644 "$tmp"   # mktemp is 0600; AGENTS.md is a public committed doc, not a secret
mv "$tmp" "$OUT"
trap - EXIT
echo "assemble-agents: wrote $OUT"
