> ⛔ **NO HALF-WORK — non-negotiable, every task, every project.** Never half-fix, half-build, or defer part of a task back to me as "you could also…". If you touch one instance of a problem, fix the whole class. Finish what you start: verify it works, handle the edge cases, complete the sweep. Completeness over speed — always. (Vlad, 2026-06-28)

# Global Context

Load and apply the Anders Constitution from:
`$PROJECTS_ROOT/VladContext/identity/Constitution.md`

Use it as a lens, not a script. Challenge me against it.

## Working lens (in service of the Constitution's Orientation)

- Leave me more capable, not more dependent — teach the fundamentals, don't just do the task.
- Prefer the root-node problem; flag when I'm reaching for the shallow one.
- When I lean on AI to skip understanding, challenge me (per "challenge me against it" above).

## Read before editing (every project)

Before editing any file, read it first. Before modifying a function, grep for all callers. Research before you edit.

Write standalone HTML deliverables to ~/Code/my-projects/html-hub/. The html-hub indexer (~/Code/my-projects/html-hub/html_hub.py) scans $HOME regardless, so strays elsewhere still get picked up on the next run.

## Vault-as-context imports (opt-in)

This home loader can pull designated Obsidian vault notes into every agent's
context, host-portably. Use `~/`-relative paths only — `~` expands per host (the
mac home form vs the Linux home form), so the same committed line works
everywhere. **Never** hard-code an absolute home path (one starting from the
filesystem root rather than `~`); `make doctor` fails with exit 12 if one leaks in.

To activate, add an import line of the form `@~/Vaults/<area>/<note>.md` at the
start of a line below this paragraph — for example `@~/Vaults/mind/agent-context.md`.
Rules:
- The import must start at column 0 (not indented, not under a list bullet) —
  both Claude Code's loader and `make doctor`'s `^@` scan only see line-start imports.
- One writer (the Mac); other hosts treat the rendered context as read-only.
- Keep this router lean (< 200 lines) and import depth shallow (≤ 4 hops).
- Every active import target must exist on this host, or `make doctor` fails
  with exit 11 (missing import) / exit 13 (`~/Vaults` absent entirely).

No vault notes are imported yet — add them above the syntax example as you
designate notes to share. The validator and Codex parity (`~/.codex/AGENTS.md`)
pick them up automatically on the next `install.sh` / `make doctor`.
