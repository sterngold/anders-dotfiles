# github-token.zsh — sourced from ~/.zshenv, so it runs in EVERY zsh context
# (login, interactive, and non-interactive `zsh -c`). Keep it minimal and fast.
#
# Exports GITHUB_PERSONAL_ACCESS_TOKEN for the plugin:github:github MCP
# (api.githubcopilot.com/mcp/), resolved dynamically from the gh keyring so no
# plaintext token lives on disk and it auto-rotates with `gh auth`. The [ -z ]
# guard skips the gh spawn when the value is already inherited (subshells).
# launchd has no shell → use ~/.local/bin/claude-mcp instead.
# See memory: github-mcp-setup. (added 2026-06-03)
#
# NOTE (fix 2026-06-06): this runs from ~/.zshenv, which is sourced BEFORE
# /etc/zprofile's path_helper and ~/.zprofile/~/.zshrc set up PATH. So at this
# point `gh` is NOT yet on PATH (and lean-ctx's `gh` alias isn't defined either),
# `command -v gh` failed, the guard skipped, and the token stayed empty for the
# whole shell — every child `claude` got a malformed `Bearer ` → HTTP 400 ✘.
# Resolve the real gh binary by absolute path (bypasses PATH timing + the alias)
# and only export a non-empty token, so a transient failure never sets `Bearer `.
if [ -z "$GITHUB_PERSONAL_ACCESS_TOKEN" ]; then
  for _gh in "$HOME/.local/bin/gh" /opt/homebrew/bin/gh /usr/local/bin/gh /usr/bin/gh; do
    [ -x "$_gh" ] || continue
    _ght="$("$_gh" auth token 2>/dev/null)"
    [ -n "$_ght" ] && export GITHUB_PERSONAL_ACCESS_TOKEN="$_ght"
    unset _ght
    break
  done
  unset _gh
fi
