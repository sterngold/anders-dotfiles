# github-token.zsh — sourced from ~/.zshenv, so it runs in EVERY zsh context
# (login, interactive, and non-interactive `zsh -c`). Keep it minimal and fast.
#
# Exports GITHUB_PERSONAL_ACCESS_TOKEN for the plugin:github:github MCP
# (api.githubcopilot.com/mcp/), resolved dynamically from the gh keyring so no
# plaintext token lives on disk and it auto-rotates with `gh auth`. The [ -z ]
# guard skips the gh spawn when the value is already inherited (subshells).
# launchd has no shell → use ~/.local/bin/claude-mcp instead.
# See memory: github-mcp-setup. (added 2026-06-03)
[ -z "$GITHUB_PERSONAL_ACCESS_TOKEN" ] && command -v gh >/dev/null 2>&1 \
  && export GITHUB_PERSONAL_ACCESS_TOKEN="$(gh auth token 2>/dev/null)"
