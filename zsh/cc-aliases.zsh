# Claude Code mode aliases (AND-640)
# Source from ~/.zprofile: [[ -f ~/anders-dotfiles/zsh/cc-aliases.zsh ]] && source ~/anders-dotfiles/zsh/cc-aliases.zsh
#
# Functions (not aliases): cd into $PROJECTS_ROOT in a subshell so cwd is preserved
# after claude exits. This ensures Claude Code discovers the workspace's .claude/skills
# chain + CLAUDE.md context regardless of where you invoke cc from.
# PROJECTS_ROOT is defined per-machine in ~/.zprofile.

cc() {
  (cd "${PROJECTS_ROOT:?PROJECTS_ROOT not set}" && CLAUDE_CONFIG_DIR="$HOME/.claude-full" claude "$@")
}

cc-build() {
  (cd "${PROJECTS_ROOT:?PROJECTS_ROOT not set}" && CLAUDE_CONFIG_DIR="$HOME/.claude-build" claude "$@")
}

cc-partner() {
  (cd "${PROJECTS_ROOT:?PROJECTS_ROOT not set}" && CLAUDE_CONFIG_DIR="$HOME/.claude-partner" claude "$@")
}
