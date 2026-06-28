#!/usr/bin/env bash
# install-managed-policy.sh — Deploy the AndersOS Claude Code Admin Policy.
#
# Renders managed-settings.json.template (expanding ${HOME} / ${PROJECTS_ROOT} to
# absolute paths for THIS host — managed-settings is root-global, so ~ is unreliable)
# and installs it as the root-owned, immutable Claude Code MANAGED settings floor at
#   /Library/Application Support/ClaudeCode/managed-settings.json   (macOS)
# This floor has the highest precedence in Claude Code: no user/project/session setting
# can override it. Canonical source of truth: this template, version-controlled here.
#
# Policy definition + rationale: 00_SYSTEM/AndersSecurity/policies/claude-code-admin-policy.md
# Drift gate: `make doctor` (anders_doctor.py `policy` group) compares deployed vs rendered.
#
# Usage:
#   bash install-managed-policy.sh            # render + sudo-install (prompts for sudo)
#   bash install-managed-policy.sh --check    # compare deployed vs canonical (no sudo)
#   bash install-managed-policy.sh --print    # render to stdout for review (no write, no sudo)
#
# Exit codes: 0 ok/in-sync · 1 drift (deployed differs) · 2 error · 3 not deployed (--check, target absent).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE="$SCRIPT_DIR/managed-settings.json.template"

# macOS managed-settings location. (Linux: /etc/claude-code/managed-settings.json —
# add a branch here if a Linux host ever joins the fleet.)
TARGET_DIR="${CLAUDE_MANAGED_DIR:-/Library/Application Support/ClaudeCode}"
TARGET="$TARGET_DIR/managed-settings.json"

PROJECTS_ROOT="${PROJECTS_ROOT:-$HOME/Code/my-projects}"

# Single source of truth for egress: the OS sandbox network allowlist is DERIVED from the
# same curated file the egress-gate.sh PreToolUse hook reads, so the two enforcement layers
# (OS seatbelt sandbox + the hook) can never drift. Default = the deployed copy the hook
# actually reads on THIS host (per-host, like managed-settings itself). Override for tests.
ALLOWLIST_SRC="${ANDERS_EGRESS_ALLOWLIST:-$HOME/.claude-full/egress-allowlist.txt}"

[[ -f "$TEMPLATE" ]] || { echo "install-managed-policy: template not found: $TEMPLATE" >&2; exit 2; }

# Render: literal-token substitution (no envsubst dependency), matching render-mcp.sh, then
# regenerate sandbox.network.allowedDomains from ALLOWLIST_SRC when python3 + the file are
# present. If either is missing, the template's literal allowedDomains floor (which keeps
# localhost/127.0.0.1) stands unchanged — a degraded host still reaches sovereign local engines.
render() {
  local content
  content="$(cat "$TEMPLATE")"
  content="${content//\$\{PROJECTS_ROOT\}/$PROJECTS_ROOT}"
  content="${content//\$\{HOME\}/$HOME}"
  if command -v python3 >/dev/null 2>&1 && [[ -f "$ALLOWLIST_SRC" ]]; then
    # Parse the allowlist (strip #-comments + whitespace, dedupe, preserve order — mirrors
    # egress-gate.sh::is_allowed) and overwrite sandbox.network.allowedDomains in the JSON.
    # The template post-substitution is valid JSON, so we load → set → re-dump deterministically.
    # Content goes in via an env var (NOT stdin) so the heredoc keeps stdin for the script.
    local regenerated
    if regenerated="$(MP_CONTENT="$content" MP_ALLOWLIST="$ALLOWLIST_SRC" python3 2>/dev/null <<'PY'
import json, os
doc = json.loads(os.environ["MP_CONTENT"])
domains, seen = [], set()
with open(os.environ["MP_ALLOWLIST"], encoding="utf-8") as fh:
    for line in fh:
        tok = line.split("#", 1)[0].strip()
        if tok and tok not in seen:
            seen.add(tok); domains.append(tok)
if not domains:                                   # empty/garbage allowlist → keep template floor
    raise SystemExit(3)
doc.setdefault("sandbox", {}).setdefault("network", {})["allowedDomains"] = domains
doc["sandbox"]["network"].pop("_comment", None)   # drop the fallback-doc note from the deployed file
print(json.dumps(doc, indent=2))
PY
    )"; then
      content="$regenerated"
    else
      echo "install-managed-policy: NOTE allowlist regeneration skipped (no usable $ALLOWLIST_SRC) — using template floor" >&2
    fi
  fi
  printf '%s\n' "$content"
}

# Validate a file as JSON; exit 2 if not.
validate_json() {
  local f="$1"
  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$f" 2>/dev/null \
      || { echo "install-managed-policy: ERROR rendered policy is not valid JSON — refusing" >&2; exit 2; }
  elif command -v jq >/dev/null 2>&1; then
    jq empty "$f" 2>/dev/null \
      || { echo "install-managed-policy: ERROR rendered policy is not valid JSON — refusing" >&2; exit 2; }
  else
    echo "install-managed-policy: NOTE no python3/jq — installing WITHOUT JSON validation" >&2
  fi
}

MODE="install"
case "${1:-}" in
  --check) MODE="check" ;;
  --print) MODE="print" ;;
  "") MODE="install" ;;
  *) echo "install-managed-policy: unknown arg '$1' (use --check | --print | no arg)" >&2; exit 2 ;;
esac

tmp="$(mktemp "${TMPDIR:-/tmp}/managed-settings.XXXXXX")"
trap 'rm -f "$tmp"' EXIT
render > "$tmp"
validate_json "$tmp"

if [[ "$MODE" == "print" ]]; then
  cat "$tmp"
  exit 0
fi

if [[ "$MODE" == "check" ]]; then
  if [[ ! -f "$TARGET" ]]; then
    echo "install-managed-policy: NOT DEPLOYED — managed policy absent ($TARGET)" >&2
    exit 3
  fi
  if diff -q "$tmp" "$TARGET" >/dev/null 2>&1; then
    echo "install-managed-policy: in sync — $TARGET matches canonical"
    # Ownership advisory (managed floor must be root-owned to be authoritative).
    owner="$(stat -f '%Su' "$TARGET" 2>/dev/null || echo '?')"
    [[ "$owner" == "root" ]] || echo "install-managed-policy: WARN deployed file owned by '$owner', expected root" >&2
    exit 0
  fi
  echo "install-managed-policy: DRIFT — $TARGET differs from canonical. Diff (deployed vs canonical):" >&2
  diff "$TARGET" "$tmp" >&2 || true
  exit 1
fi

# install mode — needs root to write /Library. Back up any existing file first.
echo "install-managed-policy: installing managed floor → $TARGET (sudo required)"
if [[ -f "$TARGET" ]]; then
  backup="$TARGET.bak-$(date -u +%Y%m%dT%H%M%SZ)"
  sudo cp -p "$TARGET" "$backup" && echo "install-managed-policy: backed up existing → $backup"
fi
sudo mkdir -p "$TARGET_DIR"
sudo cp "$tmp" "$TARGET"
sudo chown root:wheel "$TARGET"
sudo chmod 644 "$TARGET"

# Post-install verification (source of truth = the deployed file).
if diff -q "$tmp" "$TARGET" >/dev/null 2>&1; then
  owner="$(stat -f '%Su' "$TARGET" 2>/dev/null || echo '?')"
  echo "install-managed-policy: installed OK (owner=$owner). Restart Claude Code to load."
else
  echo "install-managed-policy: ERROR post-install content mismatch — investigate" >&2
  exit 2
fi
