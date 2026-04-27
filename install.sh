#!/usr/bin/env bash
# anders-dotfiles install.sh
# Idempotent — safe to re-run. Creates symlinks from ~/.claude*/ into this repo.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOME_DIR="${HOME}"

echo "anders-dotfiles: installing from $REPO into $HOME_DIR"

# Ensure target config dirs exist
for dir in .claude .claude-full .claude-build .claude-partner; do
  mkdir -p "$HOME_DIR/$dir"
done

# Helper: back up existing file if it's a real file (not already a symlink to us), then symlink
link() {
  local src="$1"
  local dst="$2"
  if [[ -L "$dst" ]]; then
    local current
    current="$(readlink "$dst")"
    if [[ "$current" == "$src" ]]; then
      echo "  OK   $dst -> $src"
      return
    fi
  fi
  if [[ -e "$dst" && ! -L "$dst" ]]; then
    local backup="$dst.pre-dotfiles.$(date +%Y%m%d_%H%M%S)"
    echo "  BACK $dst -> $backup"
    mv "$dst" "$backup"
  fi
  ln -sfn "$src" "$dst"
  echo "  LINK $dst -> $src"
}

# Helper for settings.json: bootstrap-then-leave-alone, with one-time migration
# off the legacy symlink layout. Claude Code writes UI prefs (theme, model,
# voiceEnabled, autoDreamEnabled, plugin toggles) directly to the user-scope
# settings.json on every change — symlinking it into the dotfiles repo would
# mean every preference tweak dirties git. So:
#   - if dst is a symlink to our template → migrate: replace with a real-file
#     copy of the template, so future CC writes stay machine-local
#   - if dst is a symlink elsewhere → leave alone (someone else owns it)
#   - if dst is a real file → leave alone (machine-managed, do not clobber)
#   - if dst is missing → bootstrap copy from template
# Template updates (new permissions, hooks, plugins) require a manual merge
# into each machine's live file. Use sync-settings.sh in this repo:
#   ./sync-settings.sh           # dry-run, prints what would change
#   ./sync-settings.sh --apply   # writes (with .pre-sync.<ts> backups)
manage_settings() {
  local src="$1"
  local dst="$2"
  if [[ -L "$dst" ]]; then
    local current
    current="$(readlink "$dst")"
    if [[ "$current" == "$src" ]]; then
      rm "$dst"
      cp "$src" "$dst"
      echo "  MIGR $dst (symlink -> real file; was pointing at template)"
      return
    fi
    echo "  SKIP $dst (symlink to $current, not our template)"
    return
  fi
  if [[ -e "$dst" ]]; then
    echo "  KEEP $dst (real file, machine-managed)"
    return
  fi
  cp "$src" "$dst"
  echo "  BOOT $dst (bootstrap copy from template)"
}

# ~/.claude/ static files (CC never writes these → safe to symlink)
link "$REPO/claude/CLAUDE.md"        "$HOME_DIR/.claude/CLAUDE.md"
link "$REPO/claude/statusline.sh"    "$HOME_DIR/.claude/statusline.sh"
link "$REPO/claude/keybindings.json" "$HOME_DIR/.claude/keybindings.json"

# settings.json — bootstrap-then-machine-managed (see manage_settings comment)
manage_settings "$REPO/claude/settings.json"          "$HOME_DIR/.claude/settings.json"
manage_settings "$REPO/claude-full/settings.json"     "$HOME_DIR/.claude-full/settings.json"
manage_settings "$REPO/claude-build/settings.json"    "$HOME_DIR/.claude-build/settings.json"
manage_settings "$REPO/claude-partner/settings.json"  "$HOME_DIR/.claude-partner/settings.json"

# Skills — cc-full sees the entire skill tree; cc-build and cc-partner are
# CURATED SUBSETS (per-mode allowlists), not blanket-linked. The curation
# is per-machine (Vlad-managed). Reference subset (BabyStar Apr 17):
#   cc-build:    build challenge cowork deep-load deploy excalidraw-diagram
#                frontend-design github-craft plan review-code session-wrap
#                skill-harden spec team
#   cc-partner:  brief challenge cowork deep-load resume team
# Do NOT replace the curated dirs with a blanket symlink — that defeats the
# whole point of cc-build / cc-partner being lean.
link "$HOME_DIR/.claude/skills" "$HOME_DIR/.claude-full/skills"

# Zsh aliases — source line added to ~/.zprofile if not present
ZSH_SOURCE_LINE="[[ -f $REPO/zsh/cc-aliases.zsh ]] && source $REPO/zsh/cc-aliases.zsh"
if ! grep -Fq "$REPO/zsh/cc-aliases.zsh" "$HOME_DIR/.zprofile" 2>/dev/null; then
  echo "" >> "$HOME_DIR/.zprofile"
  echo "# anders-dotfiles: Claude Code mode aliases" >> "$HOME_DIR/.zprofile"
  echo "$ZSH_SOURCE_LINE" >> "$HOME_DIR/.zprofile"
  echo "  ADD  source line in ~/.zprofile"
else
  echo "  OK   ~/.zprofile already sources cc-aliases.zsh"
fi

echo ""
echo "Done. Open a new shell or: source ~/.zprofile"
