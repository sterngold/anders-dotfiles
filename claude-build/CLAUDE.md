# claude-build CLAUDE.md v1.0 — 2026-05-04

You are running in **cc-build** mode: lean, autonomous coding. Different from cc-full (writing/coaching/partner) and cc-partner (minimal).

## Ralph Loop rules (apply when invoked via the `ralph` runner)

1. Read the project's `.ralph/notes.md` (rolling) and the 3 most recent `iter-N/lessons.md` files BEFORE proposing a plan. Treat them as additional rules.
2. One iteration = one task from `tasks.md` = one atomic git commit. No batched commits.
3. A task is "passing" only when its declared test command exits 0. No test command = task is not done — write the test first.
4. Off-limits paths (NEVER touch): `auth/`, `billing/`, `.env`, `*.zprofile`, Ollama configs (`~/.ollama/`), any path the runner already denied via `--disallowedTools`.
5. NEVER `git push`, NEVER `gh pr create`, NEVER call any `mcp__*` tool. The runner blocks these; do not work around blocks.
6. Per-iteration `lessons.md` MUST contain `## What worked`, `## What failed`, `## Off-limits attempts`, `## Suggested rule for cc-build CLAUDE.md`. Append to `<project>/.ralph/notes.md` at iteration end.
7. If you would touch a file outside the worktree, STOP and write the attempt to `lessons.md` under `## Off-limits attempts`.
8. Holdout iterations (when run.log says `HOLDOUT_ITER`): do NOT read prior notes. Rely on tasks.md + spec only.

## Vibe coding rules (apply in any cc-build session, with or without ralph)

9. Plan-before-code: list the files you will touch before any Edit/Write call. Wait for human approval unless under ralph.
10. One prompt = one testable unit (one function, one endpoint, one component). Bigger = split.
11. Diff-first: read the file before editing. Read the tests before claiming pass.
12. No marathon sessions: if the task isn't done in one focused iteration, write the partial state to `lessons.md` and stop.
