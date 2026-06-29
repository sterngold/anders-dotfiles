#!/usr/bin/env bash
# anders-dotfiles install.sh
# Idempotent — safe to re-run. Creates symlinks from ~/.claude*/ into this repo.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOME_DIR="${HOME}"

echo "anders-dotfiles: installing from $REPO into $HOME_DIR"

# Ensure target config dirs exist
# Single-profile architecture (2026-05-11): ~/.claude retired in favor of ~/.claude-full.
# ~/.claude-build also retired (merged into ~/.claude-full on 2026-05-09).
for dir in .claude-full .claude-partner; do
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
    local backup
    backup="$dst.pre-dotfiles.$(date +%Y%m%d_%H%M%S)"
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

# ~/.claude-full/ static files — single-profile CC gets the global context loader,
# statusline, and keybindings. (~/.claude retired 2026-05-11; rtk retired 2026-06-04.)
link "$REPO/claude/CLAUDE.md"        "$HOME_DIR/.claude-full/CLAUDE.md"
link "$REPO/claude/statusline.sh"    "$HOME_DIR/.claude-full/statusline.sh"
link "$REPO/claude/keybindings.json" "$HOME_DIR/.claude-full/keybindings.json"

# ~/.codex/AGENTS.md — give Codex the SAME global context as Claude's home loader,
# host-portably (target derived from $REPO per-host, so /home/<user>/... works on
# Linux). Only when Codex is set up here; never impose the layout on hosts without
# ~/.codex. link() backs up any existing real file (e.g. the empty placeholder) first.
if [[ -d "$HOME_DIR/.codex" ]]; then
  link "$REPO/claude/CLAUDE.md"      "$HOME_DIR/.codex/AGENTS.md"
else
  echo "  SKIP ~/.codex/AGENTS.md (no ~/.codex on this host — Codex not set up)"
fi

# ~/.claude-build/ — cc-build gets its own CLAUDE.md (Ralph Loop + vibe coding rules,
# scoped to autonomous-coding mode; cc-full and cc-partner do not load these).
# Spec: KnowledgeBase/specs/2026-05-04-ralph-loop-cc-build.md
# Guarded: ~/.claude-build was retired on single-profile hosts (consolidated into
# ~/.claude-full 2026-05-09). Skip cleanly when the profile dir is absent so the
# install completes — without resurrecting a retired profile. (Pre-existing block;
# left intact for hosts that still run cc-build.)
if [[ -d "$HOME_DIR/.claude-build" ]]; then
  link "$REPO/claude-build/CLAUDE.md"  "$HOME_DIR/.claude-build/CLAUDE.md"
  echo "  (legacy cc-build profile present)"
else
  echo "  SKIP ~/.claude-build/CLAUDE.md (profile retired on this host — single-profile)"
fi

# Ralph allowlist — installed into the ACTIVE profile (~/.claude-full); the ralph runner
# resolves active-then-legacy (AND-1345: .claude-build was retired out from under it).
# Bootstrap-then-user-managed. Hardblock paths (Vaults/Health/Finance/Coaching) are in the
# runner, NOT here.
if [[ -d "$HOME_DIR/.claude-full" ]]; then
  RALPH_ALLOWLIST_DST="$HOME_DIR/.claude-full/ralph-allowlist.txt"
  if [[ ! -e "$RALPH_ALLOWLIST_DST" ]]; then
    cp "$REPO/claude-build/ralph-allowlist.txt" "$RALPH_ALLOWLIST_DST"
    echo "  BOOT $RALPH_ALLOWLIST_DST (bootstrap copy)"
  else
    echo "  KEEP $RALPH_ALLOWLIST_DST (existing — user-managed)"
  fi
fi

# Ralph runner — symlinked to ~/.local/bin/ralph (must be on PATH).
# AndersStar-only enforced inside the runner via hostname check.
mkdir -p "$HOME_DIR/.local/bin"
link "$REPO/.local/bin/ralph"        "$HOME_DIR/.local/bin/ralph"

# claude-usage wrapper — pass-through to phuryn/claude-usage at ~/.local/lib/claude-usage/.
# Multi-profile scan (cc-full + cc-build + default) so stats are unified.
# Linear: AND-525 (terminal stats), AND-524 (AndersDeck panel uses the dashboard).
link "$REPO/.local/bin/claude-usage" "$HOME_DIR/.local/bin/claude-usage"

# claude-mcp — launches Claude Code with GITHUB_PERSONAL_ACCESS_TOKEN guaranteed
# set in ANY context (incl. launchd, which sources no shell files). Point launchd
# plists that run CC with plugin:github:github at this instead of bare `claude`.
# See memory: github-mcp-setup.
link "$REPO/.local/bin/claude-mcp"   "$HOME_DIR/.local/bin/claude-mcp"

# claude-usage upstream patches — apply each .patch under .local/lib/claude-usage-patches/
# to ~/.local/lib/claude-usage/ if the patch hasn't already been applied.
# Idempotent: `git apply --check` exits 0 if the patch is applicable but not yet
# applied; non-zero (e.g. "already applied") means skip. Survives `git pull` upstream.
CLAUDE_USAGE_LIB="$HOME_DIR/.local/lib/claude-usage"
CLAUDE_USAGE_PATCHES="$REPO/.local/lib/claude-usage-patches"
if [[ -d "$CLAUDE_USAGE_LIB/.git" && -d "$CLAUDE_USAGE_PATCHES" ]]; then
  for patch in "$CLAUDE_USAGE_PATCHES"/*.patch; do
    [[ -f "$patch" ]] || continue
    patch_name="$(basename "$patch")"
    if (cd "$CLAUDE_USAGE_LIB" && git apply --check "$patch") 2>/dev/null; then
      # Guard the real apply: --check can pass but apply still fail (TOCTOU vs an
      # upstream pull, mode conflict). Under set -e an unguarded failure here would
      # abort the whole install mid-run; this patch is a convenience, so warn + skip.
      if (cd "$CLAUDE_USAGE_LIB" && git apply "$patch"); then
        echo "  PATCH $CLAUDE_USAGE_LIB <- $patch_name (applied)"
      else
        echo "  WARN  git apply $patch_name failed after --check passed — claude-usage patch skipped"
      fi
    else
      echo "  PATCH $CLAUDE_USAGE_LIB <- $patch_name (already applied or non-applicable)"
    fi
  done
fi

# settings.json — bootstrap-then-machine-managed (see manage_settings comment)
# Single-profile architecture (2026-05-11): .claude and .claude-build profiles retired.
manage_settings "$REPO/claude-full/settings.json"     "$HOME_DIR/.claude-full/settings.json"
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
link "$HOME_DIR/Code/my-projects/.claude/skills" "$HOME_DIR/.claude-full/skills"
# Custom agents (operator agents for /hi /gn rituals etc.) — discovered from the
# config dir, mirroring the skills symlink above. Requires `name:` frontmatter on
# each agent file to register as an invocable subagent_type (added 2026-05-20).
link "$HOME_DIR/Code/my-projects/.claude/agents" "$HOME_DIR/.claude-full/agents"

# Zsh aliases — source line added to ~/.zprofile if not present
ZSH_SOURCE_LINE="[[ -f $REPO/zsh/cc-aliases.zsh ]] && source $REPO/zsh/cc-aliases.zsh"
if ! grep -Fq "$REPO/zsh/cc-aliases.zsh" "$HOME_DIR/.zprofile" 2>/dev/null; then
  {
    echo ""
    echo "# anders-dotfiles: Claude Code mode aliases"
    echo "$ZSH_SOURCE_LINE"
  } >> "$HOME_DIR/.zprofile"
  echo "  ADD  source line in ~/.zprofile"
else
  echo "  OK   ~/.zprofile already sources cc-aliases.zsh"
fi

# codex-dispatch — worktree-isolated headless Codex dispatch. MUST source AFTER
# cc-aliases.zsh (it reuses _cc_resolve_project / _cc_worktree_base).
CODEX_DISPATCH_LINE="[[ -f $REPO/zsh/codex-dispatch.zsh ]] && source $REPO/zsh/codex-dispatch.zsh"
if ! grep -Fq "$REPO/zsh/codex-dispatch.zsh" "$HOME_DIR/.zprofile" 2>/dev/null; then
  {
    echo ""
    echo "# anders-dotfiles: worktree-isolated Codex dispatch (after cc-aliases)"
    echo "$CODEX_DISPATCH_LINE"
  } >> "$HOME_DIR/.zprofile"
  echo "  ADD  codex-dispatch source line in ~/.zprofile"
else
  echo "  OK   ~/.zprofile already sources codex-dispatch.zsh"
fi

# GitHub MCP token — source line added to ~/.zshenv (NOT ~/.zprofile/.zshrc:
# .zshenv is the only rc sourced by non-interactive `zsh -c` shells too, so the
# token reaches every zsh context). Exports GITHUB_PERSONAL_ACCESS_TOKEN for
# plugin:github:github. launchd → ~/.local/bin/claude-mcp. See memory github-mcp-setup.
ZSHENV_SOURCE_LINE="[[ -f $REPO/zsh/github-token.zsh ]] && source $REPO/zsh/github-token.zsh"
if ! grep -Fq "$REPO/zsh/github-token.zsh" "$HOME_DIR/.zshenv" 2>/dev/null; then
  {
    echo ""
    echo "# anders-dotfiles: GitHub MCP token (all zsh contexts)"
    echo "$ZSHENV_SOURCE_LINE"
  } >> "$HOME_DIR/.zshenv"
  echo "  ADD  source line in ~/.zshenv (github-token)"
else
  echo "  OK   ~/.zshenv already sources github-token.zsh"
fi

# ── Terminal productivity stack (starship/atuin/eza/yazi/zoxide/bat + zsh plugins) ──
# Reproducible across machines: Brewfile installs the tools, config/ holds the prompt +
# history settings, zsh/terminal-stack.zsh inits them in interactive shells.

# 1. Packages — idempotent + fast when already satisfied. --no-upgrade keeps existing
#    versions. (brew bundle does not write a lockfile by default in current Homebrew.)
if command -v brew >/dev/null 2>&1; then
  if brew bundle --file="$REPO/Brewfile" --no-upgrade >/dev/null 2>&1; then
    echo "  OK   brew bundle (terminal stack)"
  else
    echo "  WARN brew bundle had issues — run manually: brew bundle --file=$REPO/Brewfile"
  fi
else
  echo "  SKIP brew bundle (no Homebrew on this host)"
fi

# 2. Configs — symlink starship prompt + atuin settings (link() backs up any real file first)
mkdir -p "$HOME_DIR/.config/atuin"
link "$REPO/config/starship.toml"     "$HOME_DIR/.config/starship.toml"
link "$REPO/config/atuin/config.toml" "$HOME_DIR/.config/atuin/config.toml"

# 3. Source line — added to ~/.zshrc (NOT ~/.zprofile: starship/atuin/autosuggestions need
#    an interactive shell). Appended last so starship init owns PROMPT/RPROMPT.
TS_SOURCE_LINE="[[ -f $REPO/zsh/terminal-stack.zsh ]] && source $REPO/zsh/terminal-stack.zsh"
if ! grep -Fq "$REPO/zsh/terminal-stack.zsh" "$HOME_DIR/.zshrc" 2>/dev/null; then
  {
    echo ""
    echo "# anders-dotfiles: terminal productivity stack (starship/atuin/eza/yazi/zoxide…)"
    echo "$TS_SOURCE_LINE"
  } >> "$HOME_DIR/.zshrc"
  echo "  ADD  source line in ~/.zshrc (terminal stack)"
else
  echo "  OK   ~/.zshrc already sources terminal-stack.zsh"
fi

# Fabrication-check hook (AND-786 Layer 1 — Structural Skeptic)
# Symlinks fabrication-check.py from anders-config into ~/.local/hooks/.
# Shell wrapper pre-commit-fabrication-check.sh calls it at the installed path.
mkdir -p "$HOME_DIR/.local/hooks"
PROJECTS_ROOT="$HOME_DIR/Code/my-projects"
FCHECK_SRC="$PROJECTS_ROOT/00_SYSTEM/anders-config/tools/fabrication-check.py"
FCHECK_DST="$HOME_DIR/.local/hooks/fabrication-check.py"
if [[ -f "$FCHECK_SRC" ]]; then
    link "$FCHECK_SRC" "$FCHECK_DST"
    chmod +x "$FCHECK_SRC"
    echo "  OK   ~/.local/hooks/fabrication-check.py -> anders-config"
else
    echo "  SKIP fabrication-check.py not found at $FCHECK_SRC (submodule missing?)"
    echo "       Install manually: ln -sf $FCHECK_SRC $FCHECK_DST"
fi

# .mcp.json — render host-portable absolute paths from the committed template.
# The live .mcp.json is gitignored (per-host); a fresh host has none until this
# runs. render-mcp.sh no-ops cleanly if the workspace isn't present on this host.
PROJECTS_ROOT="$PROJECTS_ROOT" bash "$REPO/context-sync/render-mcp.sh" \
  || echo "  WARN render-mcp.sh exited $? — .mcp.json may be stale/missing; re-run 'bash $REPO/context-sync/render-mcp.sh' or 'make -C \$PROJECTS_ROOT/00_SYSTEM/anders-config doctor'"

# GitHub transport — HTTPS-canonical (AndersOS Claude Code Admin Policy, 2026-06-27).
# The Claude Code sandbox network layer is domain-only and cannot proxy SSH (port 22), so
# git@github.com: fails in-sandbox while HTTPS (443, allowlisted) works. Rewrite GitHub SSH
# remotes to HTTPS transparently; the gh credential helper authenticates. Idempotent.
# Policy: 00_SYSTEM/AndersSecurity/policies/claude-code-admin-policy.md
git config --global url."https://github.com/".insteadOf "git@github.com:" \
  && echo "  git: GitHub SSH→HTTPS rewrite set (sandbox-compatible transport)" \
  || echo "  WARN could not set GitHub SSH→HTTPS git rewrite"

# Claude Code MANAGED admin policy — root-owned security floor at /Library (macOS).
# NOT installed automatically: it needs sudo and is a deliberate, gated step. Surface the
# command + a non-fatal drift check so a fresh/peer host is told to deploy it.
if [[ -f "$REPO/context-sync/install-managed-policy.sh" ]]; then
  if bash "$REPO/context-sync/install-managed-policy.sh" --check >/dev/null 2>&1; then
    echo "  claude managed policy: deployed + in sync"
  else
    echo "  NOTE Claude Code managed admin policy not deployed/in-sync on this host."
    echo "       Deploy (sudo): bash $REPO/context-sync/install-managed-policy.sh"
  fi
fi

# Context files: thin-pointer model (2026-05-31). AGENTS.md is the hand-edited
# canonical cross-tool source; CLAUDE.md is a STATIC pointer that imports it via
# `@AGENTS.md`. Nothing to render here — `make doctor` (§15) asserts the integrity
# (AGENTS.md present + CLAUDE.md points to it).

echo ""
echo "Done. Open a new shell or: source ~/.zprofile"
