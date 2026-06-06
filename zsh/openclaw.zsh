# OpenClaw → Anders travel profile (Mode 1, Anderson-routed)
# Source from ~/.zprofile: [[ -f ~/anders-dotfiles/zsh/openclaw.zsh ]] && source ~/anders-dotfiles/zsh/openclaw.zsh
#
# The launchd gateway `ai.openclaw.anders-travel` sets OPENCLAW_CONFIG_PATH +
# OPENCLAW_STATE_DIR itself, so the running service uses the validated travel config
# (~/.openclaw/anders-travel.json — provider `anderson` @ 127.0.0.1:3457/v1, default
# model anderson/gemma4:26b, workspace 20_PRODUCTS/TravelLog). But an INTERACTIVE shell
# has no such env, so bare `openclaw config validate` / `openclaw agents list` target
# OpenClaw's empty default profile (~/.openclaw/openclaw.json, absent) and look broken.
#
# This wrapper makes interactive `openclaw` target the SAME travel profile as the
# gateway, so config validate / agents list / models list operate on the live config.
# It steps aside when you pass --profile/--dev or pre-set the env, so other profiles
# still work. (2026-06-06)
openclaw() {
  if [[ "$*" == *--profile* || "$*" == *--dev* || -n "$OPENCLAW_CONFIG_PATH" ]]; then
    command openclaw "$@"
  else
    OPENCLAW_CONFIG_PATH="$HOME/.openclaw/anders-travel.json" \
    OPENCLAW_STATE_DIR="$HOME/.openclaw/anders-travel-state" \
    command openclaw "$@"
  fi
}
