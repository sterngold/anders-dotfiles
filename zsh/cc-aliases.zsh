# Claude Code mode aliases (AND-640) + visual session signals
# Source from ~/.zprofile: [[ -f ~/anders-dotfiles/zsh/cc-aliases.zsh ]] && source ~/anders-dotfiles/zsh/cc-aliases.zsh
#
# Functions (not aliases): cd into $PROJECTS_ROOT in a subshell so cwd is preserved
# after claude exits. This ensures Claude Code discovers the workspace's .claude/skills
# chain + CLAUDE.md context regardless of where you invoke cc from.
# PROJECTS_ROOT is defined per-machine in ~/.zprofile.
#
# Visual signals (iTerm2): each wrapper sets tab color, tab title, and two iTerm2
# user variables (cc_mode, cc_project) via OSC escape codes. The AndersStar dynamic
# profile interpolates these into its Badge Text. On exit, the trap restores defaults.
# Optional first arg = project subdir of $PROJECTS_ROOT to cd into and use as badge.
#   Examples:  cc                       # workspace root, badge "FULL · workspace"
#              cc PromptTranslator      # cd into PromptTranslator, badge "FULL · PromptTranslator"
#              cc-build FoodLog --resume

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
# Args: mode, config-dir, R, G, B, then user args ("$@" from the wrapper).
_cc_launch() {
  local mode="$1" config_dir="$2" r="$3" g="$4" b="$5"
  shift 5
  local root="${PROJECTS_ROOT:?PROJECTS_ROOT not set}"
  local target badge
  if [[ -n "$1" && -d "$root/$1" ]]; then
    target="$root/$1"; badge="$1"; shift
  else
    target="$root"; badge="workspace"
  fi
  (
    cd "$target" || return
    _cc_apply_visuals "$mode" "$badge" "$r" "$g" "$b"
    trap '_cc_reset_visuals' EXIT INT TERM
    CLAUDE_CONFIG_DIR="$config_dir" claude "$@"
  )
}

# ── Wrappers ──────────────────────────────────────────────────────────────────
# Color choices are deliberately distinct hues for at-a-glance discrimination:
#   FULL     = green   (R=  0 G=200 B= 80)  — full toolset, primary work
#   BUILD    = blue    (R= 40 G=110 B=220)  — lean coding profile
#   PARTNER  = purple  (R=160 G= 70 B=210)  — partner mode

cc() {
  _cc_launch FULL    "$HOME/.claude-full"      0 200  80 "$@"
}

cc-build() {
  _cc_launch BUILD   "$HOME/.claude-build"    40 110 220 "$@"
}

cc-partner() {
  _cc_launch PARTNER "$HOME/.claude-partner" 160  70 210 "$@"
}
