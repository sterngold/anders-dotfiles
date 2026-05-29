# Global Context

Load and apply the Anders Constitution from:
`$PROJECTS_ROOT/VladContext/identity/Constitution.md`

Use it as a lens, not a script. Challenge me against it.

## Read before editing (every project)

Before editing any file, read it first. Before modifying a function, grep for all callers. Research before you edit.

@RTK.md

## Vault-as-context imports (opt-in)

This home loader can pull designated Obsidian vault notes into every agent's
context, host-portably. Use `~/`-relative paths only — `~` expands per host (the
mac home form vs the Linux home form), so the same committed line works
everywhere. **Never** hard-code an absolute home path (one starting from the
filesystem root rather than `~`); `make doctor` fails with exit 12 if one leaks in.

To activate, add an import line of the form `@~/Vaults/<area>/<note>.md` at the
start of a line below this paragraph — for example `@~/Vaults/mind/agent-context.md`.
Rules:
- One writer (the Mac); other hosts treat the rendered context as read-only.
- Keep this router lean (< 200 lines) and import depth shallow (≤ 4 hops).
- Every active import target must exist on this host, or `make doctor` fails
  with exit 11 (missing import) / exit 13 (`~/Vaults` absent entirely).

No vault notes are imported yet — add them above the syntax example as you
designate notes to share. The validator and Codex parity (`~/.codex/AGENTS.md`)
pick them up automatically on the next `install.sh` / `make doctor`.
