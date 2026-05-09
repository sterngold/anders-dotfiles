# Claude Code mode aliases (AND-640) + visual session signals
# Source from ~/.zprofile: [[ -f ~/anders-dotfiles/zsh/cc-aliases.zsh ]] && source ~/anders-dotfiles/zsh/cc-aliases.zsh
#
# Two profiles after 2026-05-09 merge:
#   cc          — unified everyday profile (was cc-full + cc-build); AW-F7 local; sovereign tools allowed
#   cc-partner  — clean room (read-only, minimal toolset)
#
# Functions (not aliases): cd into $PROJECTS_ROOT in a subshell so cwd is preserved
# after claude exits. This ensures Claude Code discovers the workspace's .claude/skills
# chain + CLAUDE.md context regardless of where you invoke cc from.
# PROJECTS_ROOT is defined per-machine in ~/.zprofile.
#
# Visual signals (iTerm2): each wrapper sets tab color, tab title, and two iTerm2
# user variables (cc_mode, cc_project) via OSC escape codes. The AndersStar dynamic
# profile interpolates these into its Badge Text. On exit, the trap restores defaults.
#
# Optional first arg = project name. Resolution (in order):
#   1. Direct child of $PROJECTS_ROOT (back-compat for pre-Work-3.0 layout)
#   2. Two-level search under category dirs (00_SYSTEM, 10_AI_OS, 20_PRODUCTS,
#      30_DOMAINS, 40_EXPERIMENTS, 90_ARCHIVE) — exact case-insensitive match
#   3. Explicit relative path (e.g. 20_PRODUCTS/Nudge) — works as a normal dir
# Multiple matches across categories abort with disambiguation hint.
# Tab-completion lists all direct children + grandchildren under category dirs.
#
#   Examples:  cc                       # workspace root, badge "CC · workspace"
#              cc Nudge                 # → 20_PRODUCTS/Nudge,    badge "CC · Nudge"
#              cc Anderson              # → 10_AI_OS/Anderson,    badge "CC · Anderson"
#              cc FoodLog --resume
#              cc 20_PRODUCTS/Nudge     # explicit path also works
#              cc-partner               # clean-room, badge "PARTNER · workspace"

# ── Internal helpers ──────────────────────────────────────────────────────────
# Emit OSC 1337 SetUserVar=<key>=<base64(value)> — sets an iTerm2 user variable
# that the badge / status bar / window title can interpolate as \(user.<key>).
_cc_set_user_var() {
  local key="$1" val="$2" b64
  b64=$(printf '%s' "$val" | base64 | tr -d '\n')
  printf '\e]1337;SetUserVar=%s=%s\a' "$key" "$b64"
}

# Set tab color via OSC 6 (iTerm2 proprietary). Components 0-255.
_cc_set_tab_color() {
  local r="$1" g="$2" b="$3"
  printf '\e]6;1;bg;red;brightness;%d\a'   "$r"
  printf '\e]6;1;bg;green;brightness;%d\a' "$g"
  printf '\e]6;1;bg;blue;brightness;%d\a'  "$b"
}

# Reset tab color to profile default.
_cc_reset_tab_color() {
  printf '\e]6;1;bg;*;default\a'
}

# Set tab/window title via OSC 0 (standard).
_cc_set_title() {
  printf '\e]0;%s\a' "$1"
}

# Apply the full visual signal set: tab color + title + user vars.
# Args: mode (FULL|BUILD|PARTNER), project, R, G, B
_cc_apply_visuals() {
  local mode="$1" proj="$2" r="$3" g="$4" b="$5"
  _cc_set_tab_color "$r" "$g" "$b"
  _cc_set_title "${proj} · ${mode}"
  _cc_set_user_var cc_mode    "$mode"
  _cc_set_user_var cc_project "$proj"
}

# Reset all visuals to default.
_cc_reset_visuals() {
  _cc_reset_tab_color
  _cc_set_user_var cc_mode    ""
  _cc_set_user_var cc_project ""
  # Do not reset title — shell-prompt / next command will reclaim it.
}

# Core launcher: shared between all three wrappers.
# Args: mode, config-dir, R, G, B, model_class, then user args ("$@" from the wrapper).
# model_class drives AW-F7 sovereignty guard (anders-config/specs/2026-04-24-aw-f7…):
#   local         — sovereign tools (anders_health_query / anders_fin_query /
#                   anders_coach_ask) may run; the agent class is on-host inference.
#   remote_egress — sovereign tools refuse via T6 / S2; the agent class talks to a
#                   cloud model (Anthropic / OpenAI / etc.) and must not see vault data.
# Workspace categories that may hold projects as grandchildren of $PROJECTS_ROOT.
# Order is irrelevant for resolution; case-insensitive exact match decides.
_CC_CATEGORIES=(00_SYSTEM 10_AI_OS 20_PRODUCTS 30_DOMAINS 40_EXPERIMENTS 90_ARCHIVE)

# Resolve a project name → absolute directory.
# Echoes the resolved path on stdout, or prints an error to stderr and returns 1.
# Resolution rules (first match wins):
#   1. $root/$name (direct child)
#   2. $root/<category>/$name (two-level, case-insensitive, exact)
#   3. $name itself if it is already a directory under $root
_cc_resolve_project() {
  local root="$1" name="$2"
  # Rule 3: explicit relative path like "20_PRODUCTS/Nudge"
  if [[ "$name" == */* && -d "$root/$name" ]]; then
    printf '%s\n' "$root/$name"; return 0
  fi
  # Rule 1: direct child
  if [[ -d "$root/$name" ]]; then
    printf '%s\n' "$root/$name"; return 0
  fi
  # Rule 2: two-level case-insensitive exact match
  local cat dir matches=()
  local lname="${name:l}"
  for cat in "${_CC_CATEGORIES[@]}"; do
    [[ -d "$root/$cat" ]] || continue
    for dir in "$root/$cat"/*(N/); do
      local base="${dir:t}"
      [[ "${base:l}" == "$lname" ]] && matches+=("$dir")
    done
  done
  case ${#matches[@]} in
    0) printf 'cc: no project named %s under %s\n' "$name" "$root" >&2; return 1 ;;
    1) printf '%s\n' "${matches[1]}"; return 0 ;;
    *) printf 'cc: ambiguous project name %s — matches:\n' "$name" >&2
       local m; for m in "${matches[@]}"; do printf '  %s\n' "${m#$root/}" >&2; done
       printf 'Use the full path: cc-* %s\n' "${matches[1]#$root/}" >&2
       return 1 ;;
  esac
}

_cc_launch() {
  local mode="$1" config_dir="$2" r="$3" g="$4" b="$5" model_class="$6"
  shift 6
  local root="${PROJECTS_ROOT:?PROJECTS_ROOT not set}"
  local target badge
  if [[ -n "$1" ]]; then
    target=$(_cc_resolve_project "$root" "$1") || return 1
    badge="${target:t}"
    shift
  else
    target="$root"; badge="workspace"
  fi
  (
    cd "$target" || return
    _cc_apply_visuals "$mode" "$badge" "$r" "$g" "$b"
    trap '_cc_reset_visuals' EXIT INT TERM
    AW_F7_MODEL_CLASS="$model_class" CLAUDE_CONFIG_DIR="$config_dir" claude --add-dir "$HOME/Vaults" "$@"
  )
}

# ── Wrappers ──────────────────────────────────────────────────────────────────
# Color choices are deliberately distinct hues for at-a-glance discrimination:
#   CC       = green   (R=  0 G=200 B= 80)  — unified everyday profile (post 2026-05-09 merge)
#   PARTNER  = purple  (R=160 G= 70 B=210)  — clean-room
#
# AW-F7 model class: cc uses `local` (sovereign tools allowed), cc-partner uses
# `remote_egress` (sovereign tools refused — clean room must not see vault data).

cc() {
  _cc_launch CC      "$HOME/.claude-full"      0 200  80 local "$@"
}

cc-partner() {
  _cc_launch PARTNER "$HOME/.claude-partner" 160  70 210 remote_egress "$@"
}

# ── Tab completion ────────────────────────────────────────────────────────────
# Lists every project as the first arg: direct children of $PROJECTS_ROOT plus
# every grandchild under category dirs. After the project arg, falls back to
# normal file completion so `--resume`, paths, etc. still work.
_cc_projects() {
  local root="${PROJECTS_ROOT}"
  [[ -z "$root" || ! -d "$root" ]] && return 1
  local -a projects
  local cat dir base
  # Direct children (non-category dirs only — keep the project list clean).
  for dir in "$root"/*(N/); do
    base="${dir:t}"
    case "$base" in
      00_SYSTEM|10_AI_OS|20_PRODUCTS|30_DOMAINS|40_EXPERIMENTS|90_ARCHIVE) ;;
      *) projects+=("$base") ;;
    esac
  done
  # Grandchildren under each category.
  for cat in "${_CC_CATEGORIES[@]}"; do
    [[ -d "$root/$cat" ]] || continue
    for dir in "$root/$cat"/*(N/); do
      projects+=("${dir:t}")
    done
  done
  if (( CURRENT == 2 )); then
    _describe -t projects 'project' projects
  else
    _files
  fi
}
# Only register completion if compinit has run (skips non-interactive contexts).
(( $+functions[compdef] )) && compdef _cc_projects cc cc-partner
