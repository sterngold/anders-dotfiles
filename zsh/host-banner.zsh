# host-banner.zsh — per-machine identity banner for interactive login shells.
#
# Sourced from cc-aliases.zsh (which ~/.zprofile loads → runs once per terminal
# window/tab). Replaces the old iTerm2 "Send text at start" / Initial Text approach,
# which double-interpreted printf escapes and mangled pasted quotes. Living in zsh
# means: no iTerm field, no quote/escape fragility, survives any profile deletion,
# and works identically on every machine that pulls the dotfiles.
#
# AndersStar = rainbow pride · BabyStar = trans pride · other hosts = a plain line.
# Colors via zsh prompt expansion (%F{n}/%B/%b/%f); live date via %D{} (strftime) —
# no backslashes, no command substitution.

_anders_host_banner() {
  # Only real interactive terminals — never pollute scripts / `ssh host cmd` output.
  [[ -o interactive && -t 1 ]] || return
  # Guard against double-fire (.zshrc sources .zprofile for non-login shells,
  # but login shells run .zprofile first → banner would show twice without this).
  [[ -n ${_ANDERS_BANNER_SHOWN:-} ]] && return
  export _ANDERS_BANNER_SHOWN=1
  local h="${HOST:-$(hostname -s)}"; h="${h:l}"   # lowercase → match regardless of host casing
  print -P ''
  case "$h" in
    andersstar*)
      print -P '  %F{196}▰%F{208}▰%F{226}▰%F{46}▰%F{33}▰%F{129}▰%f  %B%F{196}A%F{208}n%F{226}d%F{154}e%F{46}r%F{51}s%F{33}S%F{27}t%F{93}a%F{201}r%b%f'
      print -P '          %F{245}M5 Max · 128 GB · primary at home  ·  %D{%a %d %b · %H:%M}%f'
      ;;
    babystar*)
      print -P '  %F{117}▰▰%F{218}▰▰%F{231}▰▰%F{218}▰▰%F{117}▰▰%f  %B%F{117}B%F{218}a%F{231}b%F{218}y%F{117}S%F{218}t%F{231}a%F{218}r%b%f  %F{117}✈%f'
      print -P '          %F{117}M5 Air%f %F{245}·%f %F{218}travel mode%f  %F{245}·  %D{%a %d %b · %H:%M}%f'
      ;;
    *)
      print -P "  %B%F{252}${h}%b%f  %F{245}·  %D{%a %d %b · %H:%M}%f"
      ;;
  esac
  print -P ''
}

_anders_host_banner
