#!/usr/bin/env zsh
# launchd-ops.zsh — reload-service <label>: the one correct launchd reload sequence.
#
# WHY THIS EXISTS
#   A WorkingDirectory/env change needs a full bootout→bootstrap reload (kickstart -k
#   won't pick it up), but the naive sequence is a footgun that cost a live outage
#   (2026-07-15): bootout→bootstrap immediately EIOs (race — the job hasn't settled),
#   and `enable && bootstrap` short-circuits because enable exits non-zero on an
#   already-enabled job. Correct sequence (memory reference_launchd_reload_sequence):
#   bootout → sleep 3 → enable (NO &&) → bootstrap → retry once.
#
#   NB: launchctl GUI-domain ops fail with EIO inside the Claude Code sandbox —
#   this function is for a real terminal.

reload-service() {
  emulate -L zsh
  local label="${1%.plist}"
  if [[ -z "$label" ]]; then
    print -u2 "usage: reload-service <launchd-label>   (e.g. com.sterngold.t2.merelin)"
    return 64
  fi
  local plist="$HOME/Library/LaunchAgents/${label}.plist"
  if [[ ! -f "$plist" ]]; then
    print -u2 "reload-service: no plist at $plist"
    return 66
  fi
  local domain="gui/$UID"

  launchctl bootout "$domain/$label" 2>/dev/null   # tolerate not-loaded
  sleep 3                                          # settle the bootout race (EIO otherwise)
  launchctl enable "$domain/$label"                # exits non-zero when already enabled — never && this
  if ! launchctl bootstrap "$domain" "$plist"; then
    print -u2 "reload-service: bootstrap failed once (EIO race?) — retrying in 3s"
    sleep 3
    if ! launchctl bootstrap "$domain" "$plist"; then
      print -u2 "reload-service: bootstrap failed twice for $label — inspect: launchctl print $domain/$label"
      return 1
    fi
  fi
  launchctl print "$domain/$label" 2>/dev/null | grep -E 'state|last exit code|path' | head -4
  print "reload-service: $label reloaded."
}
