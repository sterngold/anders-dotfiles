# RTK - Rust Token Killer (retired locally)

**Status as of 2026-06-07**: RTK is no longer part of the active Claude Code token-management stack on this machine.

## Current decision

Use **Lean Context** as the single active reducer, configured `minimal` + `agents-only`.
Use **ccusage** as a read-only measurement layer.
Do **not** run `rtk init -g` unless explicitly replacing Lean Context.

## Why RTK was retired

Local verification showed:

```bash
rtk gain     # No tracking data yet
rtk session  # No hook installed
```

RTK was installed but not active, while Lean Context was already wired into Claude Code hooks and reporting real savings.
Running both would add duplicate command-rewrite policy and increase drift risk.

## Reversible rollback

The binary was not deleted. It was renamed to:

```bash
~/.local/bin/rtk.disabled-20260607_agent_only_lean
```

To restore RTK manually:

```bash
mv ~/.local/bin/rtk.disabled-20260607_agent_only_lean ~/.local/bin/rtk
rtk --version
```

Only after explicitly deciding to replace Lean Context:

```bash
rtk init -g
rtk session
rtk gain
```
