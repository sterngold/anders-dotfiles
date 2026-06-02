# anders-dotfiles — portable interactive terminal stack
#
# Sourced from ~/.zshrc (INTERACTIVE shells only — starship/atuin/autosuggestions
# need ZLE). install.sh adds the source line; tools come from the repo Brewfile:
#     brew bundle --file ~/anders-dotfiles/Brewfile
#
# Every block is command-guarded so a missing tool degrades gracefully instead of
# erroring — this file is safe to source on any machine, fully or partially provisioned.

# Homebrew prefix — honour an existing env value (set by `brew shellenv`), else the
# Apple-Silicon default. Intel hosts that export HOMEBREW_PREFIX=/usr/local still work.
: ${HOMEBREW_PREFIX:=/opt/homebrew}

# zoxide — smarter cd (`z foo` jumps to most-frequented match)
command -v zoxide >/dev/null && eval "$(zoxide init zsh)"

# fzf — fuzzy finder + Ctrl-T (files) / Alt-C (cd). Prefer the modern `fzf --zsh`
# integration; fall back to the shipped shell files on older fzf.
if command -v fzf >/dev/null; then
  if fzf --zsh >/dev/null 2>&1; then
    source <(fzf --zsh)
  else
    [ -f "$HOMEBREW_PREFIX/opt/fzf/shell/key-bindings.zsh" ] && source "$HOMEBREW_PREFIX/opt/fzf/shell/key-bindings.zsh"
    [ -f "$HOMEBREW_PREFIX/opt/fzf/shell/completion.zsh" ]   && source "$HOMEBREW_PREFIX/opt/fzf/shell/completion.zsh"
  fi
fi

# zsh-autosuggestions — history-based ghost-text (→ accepts)
[ -f "$HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ] && \
  source "$HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh"

# fast-syntax-highlighting — MUST load AFTER autosuggestions (last-loaded plugin wraps ZLE widgets)
_fsh="$HOMEBREW_PREFIX/opt/zsh-fast-syntax-highlighting/share/zsh-fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh"
[ -f "$_fsh" ] && source "$_fsh"
unset _fsh

# atuin — searchable cross-session history (rebinds Ctrl-R + Up; after fzf so atuin wins).
# Offline-only by default — no `atuin register` / `atuin login`, so nothing leaves the host.
command -v atuin >/dev/null && eval "$(atuin init zsh)"

# yazi — `yy` opens yazi and cd's to its last directory on exit (plain `yazi` doesn't)
if command -v yazi >/dev/null; then
  function yy() {
    local tmp; tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
    yazi "$@" --cwd-file="$tmp"
    if cwd="$(cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
      builtin cd -- "$cwd"
    fi
    rm -f -- "$tmp"
  }
fi

# eza — ls replacements (interactive aliases only; scripts and `command ls` bypass them)
if command -v eza >/dev/null; then
  alias ls='eza --icons=auto --group-directories-first'
  alias ll='eza -lah --icons=auto --group-directories-first --git --time-style=long-iso'
  alias la='eza -a --icons=auto --group-directories-first'
  alias lt='eza --tree --level=2 --icons=auto --group-directories-first --git-ignore'
  alias lT='eza --tree --level=3 --icons=auto --group-directories-first --git-ignore'
fi

# starship — LAST so it owns PROMPT/RPROMPT
command -v starship >/dev/null && eval "$(starship init zsh)"
