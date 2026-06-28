#!/bin/bash
# Sterngold Status Line — bold pride palette (rainbow, Jun 2026)
# Reads JSON from stdin (Claude Code status line protocol)
#
# Palette uses ANSI 256-color indices, all BOLD (rendered via \033[1;38;5;Nm).
# Pride rainbow: 196 red · 208 orange · 226 yellow · 46 green · 39 blue · 129 violet.
# Semantic mapping below keeps the info-bar meaning (good/info/warn/critical)
# while painting it in pride hues; the leading ▰▰▰▰▰▰ is a 6-stripe pride flag.

CACHE_DIR="/tmp/claude-statusline"
LOG="$CACHE_DIR/error.log"
mkdir -p "$CACHE_DIR" 2>/dev/null

# Ensure python3.12 is on PATH (framework install not in default bash PATH)
export PATH="/usr/local/bin:/Library/Frameworks/Python.framework/Versions/3.12/bin:$PATH"

# Read JSON from stdin
INPUT=$(cat)

# 256-color codes — bold pride palette
G="\033[1;38;5;46m"   # green  — positive/good state
B="\033[1;38;5;39m"   # blue   — info/branches
P="\033[1;38;5;129m"  # violet — opus/special
Y="\033[1;38;5;214m"  # amber  — warning
W="\033[1;38;5;255m"  # bright white — default text
D="\033[1;38;5;245m"  # gray   — dim/secondary
RED="\033[1;38;5;196m" # red    — critical
R="\033[0m"           # reset
SEP="\033[1;38;5;129m▏${R}"   # bold violet separator

# Pride-flag prefix (6 stripes: red·orange·yellow·green·blue·violet)
STAR="\033[1;38;5;196m▰\033[1;38;5;208m▰\033[1;38;5;226m▰\033[1;38;5;46m▰\033[1;38;5;39m▰\033[1;38;5;129m▰${R}"

# ── Parse JSON once ────────────────────────────
PARSED=$(echo "$INPUT" | python3.12 -c "
import sys, json, os
LOG = '$LOG'
try:
    d = json.loads(sys.stdin.read())
    m = d.get('model', {})
    c = d.get('context_window', {})
    cost = d.get('cost', {})
    style = d.get('output_style', {}).get('name', 'default')
    wt = d.get('worktree', {})

    # Fallback: if JSON says 'default', check settings.json for enabled output-style plugins
    # Cached by mtime to avoid reading settings.json on every render
    import re
    if style == 'default':
        try:
            settings_path = os.path.expanduser('~/.claude/settings.json')
            cache_path = os.path.join('$CACHE_DIR', 'style')
            settings_mtime = os.path.getmtime(settings_path)
            cache_mtime = os.path.getmtime(cache_path) if os.path.exists(cache_path) else 0
            if cache_mtime >= settings_mtime:
                style = open(cache_path).read().strip() or 'default'
            else:
                with open(settings_path) as sf:
                    plugins = json.load(sf).get('enabledPlugins', {})
                for pname, enabled in plugins.items():
                    match = re.search(r'(\w+)-output-style', pname)
                    if enabled and match:
                        style = match.group(1)
                        break
                with open(cache_path, 'w') as cf:
                    cf.write(style)
        except Exception:
            pass

    # Model
    print(m.get('display_name', '?'))

    # Context: percentage-based (actual window fill)
    ws = int(c.get('context_window_size', 0) or 0)
    pct = float(c.get('used_percentage', 0) or 0)
    used = int(ws * pct / 100) if ws else 0
    print(int(pct))
    print(used)
    print(ws)

    # Session duration
    print(f\"{(cost.get('total_duration_ms', 0) or 0) / 1000:.0f}\")

    # Cost
    print(f\"{(cost.get('total_cost_usd', 0) or 0):.2f}\")

    # Lines changed
    added = int(cost.get('total_lines_added', 0) or 0)
    removed = int(cost.get('total_lines_removed', 0) or 0)
    print(f\"{added} {removed}\")

    # Output style / mode
    print(style)

    # Worktree name (empty if not in worktree)
    print(wt.get('name', ''))

    # Model ID (for extended context detection)
    print(m.get('id', ''))

except Exception as e:
    with open(LOG, 'a') as f:
        f.write(f'{e}\n')
    for _ in range(10):
        print('?')
" 2>>"$LOG")

MODEL=$(echo "$PARSED" | sed -n '1p')
CTX_PCT=$(echo "$PARSED" | sed -n '2p')
CTX_TOKENS=$(echo "$PARSED" | sed -n '3p')
SESSION_SECS=$(echo "$PARSED" | sed -n '5p')
COST_USD=$(echo "$PARSED" | sed -n '6p')
LINES_CHANGED=$(echo "$PARSED" | sed -n '7p')
OUTPUT_STYLE=$(echo "$PARSED" | sed -n '8p')
WORKTREE=$(echo "$PARSED" | sed -n '9p')
MODEL_ID=$(echo "$PARSED" | sed -n '10p')

# Fallback for parse failures
CTX_PCT="${CTX_PCT:-0}"; CTX_TOKENS="${CTX_TOKENS:-0}"; SESSION_SECS="${SESSION_SECS:-0}"
COST_USD="${COST_USD:-0.00}"; LINES_CHANGED="${LINES_CHANGED:-0 0}"

# ── Model + Mode ──────────────────────────────
case "$MODEL" in
  *Opus*|*opus*)     M_COLOR="$P"; M_SHORT="opus" ;;
  *Sonnet*|*sonnet*) M_COLOR="$B"; M_SHORT="sonnet" ;;
  *Haiku*|*haiku*)   M_COLOR="$G"; M_SHORT="haiku" ;;
  *)                 M_COLOR="$W"; M_SHORT="$MODEL" ;;
esac

# Extended context indicator
case "$MODEL_ID" in
  *\[1m\]*|*1m*) M_SHORT="${M_SHORT}${D}/1M${R}" ;;
esac

# Output style badge (skip if default)
if [ -n "$OUTPUT_STYLE" ] && [ "$OUTPUT_STYLE" != "default" ]; then
  M_SHORT="${M_SHORT} ${D}[${W}${OUTPUT_STYLE}${D}]${R}"
fi

# Mode indicator (CLAUDE_CONFIG_DIR-based) — also captured for OSC 1337 emission below
case "${CLAUDE_CONFIG_DIR:-}" in
  *full*)    CC_MODE="FULL"    ; M_SHORT="${M_SHORT} ${G}[FULL]${R}" ;;
  *build*)   CC_MODE="BUILD"   ; M_SHORT="${M_SHORT} ${B}[BUILD]${R}" ;;
  *partner*) CC_MODE="PARTNER" ; M_SHORT="${M_SHORT} ${P}[PARTNER]${R}" ;;
  *)         CC_MODE="" ;;
esac

# Project name from PWD relative to $PROJECTS_ROOT (first segment, or "workspace" at root)
PROJ_NAME="workspace"
if [ -n "${PROJECTS_ROOT:-}" ] && [ -n "${PWD:-}" ]; then
  case "$PWD" in
    "$PROJECTS_ROOT")     PROJ_NAME="workspace" ;;
    "$PROJECTS_ROOT"/*)   PROJ_NAME="${PWD#"$PROJECTS_ROOT"/}"; PROJ_NAME="${PROJ_NAME%%/*}" ;;
    *)                    PROJ_NAME="$(basename "$PWD")" ;;
  esac
fi
M_SHORT="${M_SHORT} ${D}${PROJ_NAME}${R}"

# ── Context: tokens + bar + wrap warning ───────
if [ "$CTX_TOKENS" -ge 1000000 ] 2>/dev/null; then
  TOK_DISPLAY="$(( CTX_TOKENS / 1000000 )).$(( (CTX_TOKENS % 1000000) / 100000 ))M"
elif [ "$CTX_TOKENS" -ge 1000 ] 2>/dev/null; then
  TOK_DISPLAY="$(( CTX_TOKENS / 1000 ))K"
else
  TOK_DISPLAY="${CTX_TOKENS}"
fi

# Color thresholds based on context window percentage
if [ "$CTX_PCT" -lt 30 ] 2>/dev/null; then
  CTX_COLOR="$G"; CTX_WARN=""
elif [ "$CTX_PCT" -lt 60 ] 2>/dev/null; then
  CTX_COLOR="$Y"; CTX_WARN=""
elif [ "$CTX_PCT" -lt 80 ] 2>/dev/null; then
  CTX_COLOR="$Y"; CTX_WARN=" ${Y}→ wrap${R}"
else
  CTX_COLOR="$RED"; CTX_WARN=" ${RED}⚠ COMPACT${R}"
fi

# Mini bar (5 segments, based on percentage)
FILLED=$(( CTX_PCT / 20 ))
[ "$FILLED" -gt 5 ] && FILLED=5
EMPTY=$(( 5 - FILLED ))
BAR=""
for ((i=0; i<FILLED; i++)); do BAR+="▰"; done
for ((i=0; i<EMPTY; i++)); do BAR+="▱"; done

# ── Code delta ────────────────────────────────
ADDED=$(echo "$LINES_CHANGED" | cut -d' ' -f1)
REMOVED=$(echo "$LINES_CHANGED" | cut -d' ' -f2)
ADDED="${ADDED:-0}"; REMOVED="${REMOVED:-0}"
if [ "$ADDED" -gt 0 ] 2>/dev/null || [ "$REMOVED" -gt 0 ] 2>/dev/null; then
  DELTA_SEG="${G}+${ADDED}${R}${D}/${R}${RED}-${REMOVED}${R}"
else
  DELTA_SEG=""
fi

# ── Session cost ──────────────────────────────
if [ "$COST_USD" != "0.00" ] && [ "$COST_USD" != "?" ] 2>/dev/null; then
  COST_SEG="${D}\$${W}${COST_USD}${R}"
else
  COST_SEG=""
fi

# ── Session duration ──────────────────────────
if [ "$SESSION_SECS" -gt 0 ] 2>/dev/null; then
  S_MIN=$(( SESSION_SECS / 60 ))
  if [ "$S_MIN" -ge 60 ]; then
    S_DISPLAY="$(( S_MIN / 60 ))h$(( S_MIN % 60 ))m"
  else
    S_DISPLAY="${S_MIN}m"
  fi
  TIME_SEG="${D}${S_DISPLAY}${R}"
else
  TIME_SEG=""
fi

# ── Usage limits (cached 60s) ─────────────────
USAGE_CACHE="$CACHE_DIR/usage"
USAGE_AGE=999
[ -f "$USAGE_CACHE" ] && USAGE_AGE=$(( $(date +%s) - $(stat -f %m "$USAGE_CACHE" 2>/dev/null || echo 0) ))
if [ "$USAGE_AGE" -gt 60 ]; then
  TOKEN=$(security find-generic-password -s 'Claude Code-credentials' -w 2>/dev/null | python3.12 -c "import sys,json; print(json.loads(sys.stdin.read()).get('claudeAiOauth',{}).get('accessToken',''))" 2>/dev/null)
  if [ -n "$TOKEN" ]; then
    RESP=$(curl -sf -H "Authorization: Bearer $TOKEN" -H "anthropic-beta: oauth-2025-04-20" -H "Content-Type: application/json" "https://api.anthropic.com/api/oauth/usage" 2>/dev/null)
    echo "$RESP" | python3.12 -c "
import sys,json
d=json.loads(sys.stdin.read())
print(int(d.get('five_hour',{}).get('utilization',0) or 0), int(d.get('seven_day',{}).get('utilization',0) or 0))
" > "$USAGE_CACHE" 2>/dev/null || echo "0 0" > "$USAGE_CACHE"
  else
    echo "0 0" > "$USAGE_CACHE"
    echo "$(date): OAuth token extraction failed" >> "$LOG"
  fi
fi
read -r H5_PCT D7_PCT < "$USAGE_CACHE" 2>/dev/null
H5_PCT="${H5_PCT:-0}"; D7_PCT="${D7_PCT:-0}"
if [ "$H5_PCT" -lt 50 ] 2>/dev/null; then H5_C="$G"; elif [ "$H5_PCT" -lt 80 ] 2>/dev/null; then H5_C="$Y"; else H5_C="$RED"; fi
if [ "$D7_PCT" -lt 50 ] 2>/dev/null; then D7_C="$G"; elif [ "$D7_PCT" -lt 80 ] 2>/dev/null; then D7_C="$Y"; else D7_C="$RED"; fi

# ── Git branch ────────────────────────────────
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
if [ -n "$BRANCH" ]; then
  DIRTY=$(git status --porcelain 2>/dev/null | head -1)
  if [ -n "$DIRTY" ]; then
    GIT_SEG="${B}⎇ ${BRANCH} ${Y}●${R}"
  else
    GIT_SEG="${B}⎇ ${BRANCH}${R}"
  fi
else
  GIT_SEG=""
fi

# ── Worktree indicator ────────────────────────
if [ -n "$WORKTREE" ] && [ "$WORKTREE" != "?" ]; then
  GIT_SEG="${P}⊕ ${WORKTREE}${R}"
fi

# ── Working mode (plan/exec) + thinking level ─
MODE_FILE="$CACHE_DIR/mode"
THINK_FILE="$CACHE_DIR/thinking"
MODE_SEG=""
if [ -f "$MODE_FILE" ]; then
  WM=$(cat "$MODE_FILE" 2>/dev/null)
  case "$WM" in
    plan) MODE_SEG="${Y}◇ plan${R}" ;;
  esac
fi
if [ -f "$THINK_FILE" ]; then
  TL=$(cat "$THINK_FILE" 2>/dev/null)
  case "$TL" in
    ultra) THINK_SEG="${P}⚡ultra${R}" ;;
    high)  THINK_SEG="${Y}↑high${R}" ;;
    low)   THINK_SEG="${D}↓low${R}" ;;
    auto)  THINK_SEG="${D}~auto${R}" ;;
    *)     THINK_SEG="" ;;
  esac
  [ -n "$MODE_SEG" ] && [ -n "$THINK_SEG" ] && MODE_SEG="${MODE_SEG} ${THINK_SEG}"
  [ -z "$MODE_SEG" ] && MODE_SEG="$THINK_SEG"
fi

# ── Assemble ──────────────────────────────────
PARTS="${STAR} ${SEP} ${M_COLOR}${M_SHORT}${R}"

# Mode + thinking (right after model)
[ -n "$MODE_SEG" ] && PARTS="${PARTS} ${MODE_SEG}"

PARTS="${PARTS} ${SEP} ${CTX_COLOR}${BAR} ${TOK_DISPLAY}${CTX_WARN}${R}"

# Rate limits (hide when both are 0%)
if [ "$H5_PCT" -gt 0 ] 2>/dev/null || [ "$D7_PCT" -gt 0 ] 2>/dev/null; then
  PARTS="${PARTS} ${SEP} ${H5_C}5h:${H5_PCT}%${R} ${D7_C}7d:${D7_PCT}%${R}"
fi

# Code delta (only if code was changed)
[ -n "$DELTA_SEG" ] && PARTS="${PARTS} ${SEP} ${DELTA_SEG}"

# Cost
[ -n "$COST_SEG" ] && PARTS="${PARTS} ${SEP} ${COST_SEG}"

# Git / Worktree
[ -n "$GIT_SEG" ] && PARTS="${PARTS} ${SEP} ${GIT_SEG}"

# Duration
[ -n "$TIME_SEG" ] && PARTS="${PARTS} ${SEP} ${TIME_SEG}"

# Emit iTerm2 user variables (OSC 1337) every render so the AndersStar profile
# badge — which interpolates \(user.cc_mode) and \(user.cc_project) — stays in sync
# with cwd changes made *inside* Claude (cd into a different project subdir).
if [ -n "${TERM_PROGRAM:-}" ] && [ "$TERM_PROGRAM" = "iTerm.app" ]; then
  CC_MODE_B64=$(printf '%s' "${CC_MODE:-}"   | base64 | tr -d '\n')
  PROJ_B64=$(   printf '%s' "${PROJ_NAME:-}" | base64 | tr -d '\n')
  printf '\033]1337;SetUserVar=cc_mode=%s\007'    "$CC_MODE_B64"
  printf '\033]1337;SetUserVar=cc_project=%s\007' "$PROJ_B64"
fi

echo -e "$PARTS"
