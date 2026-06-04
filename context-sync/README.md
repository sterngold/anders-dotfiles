# context-sync — portable AI-context layer

Makes the shared agent-context layer (home `CLAUDE.md`, `.mcp.json`, the
`~/.codex/AGENTS.md` parity link, security/way-of-working rules) **host-portable**:
edit once on the writer host (the Mac), and any peer host — mac today, a Linux
VPS later — becomes a full peer with one idempotent run.

## Setup on a fresh host

```sh
# 1. Clone the repos (anders-dotfiles + my-projects alongside each other)
git clone git@github.com:sterngold/anders-dotfiles.git ~/anders-dotfiles
git clone --recurse-submodules git@github.com:sterngold/my-projects.git ~/Code/my-projects

# 2. One idempotent install (creates symlinks, renders .mcp.json)
bash ~/anders-dotfiles/install.sh

# 3. Validate
make -C ~/Code/my-projects/00_SYSTEM/anders-config doctor
```

`install.sh` is safe to re-run; a second run shows only `OK`/no-change lines.

## What's shared vs machine-specific

| Layer | Tracked? | Notes |
|---|---|---|
| `claude/CLAUDE.md` (home loader) | committed | the durable, shared context — edit here |
| `context-sync/mcp.json.template` | committed | `${HOME}` / `${PROJECTS_ROOT}` tokens only — never absolute paths |
| `$PROJECTS_ROOT/.mcp.json` | **gitignored** | rendered per-host by `render-mcp.sh`; absolute paths at runtime |
| `CLAUDE.local.md` | **gitignored** | machine-specific operating notes |
| `~/.claude-full/CLAUDE.md`, `~/.codex/AGENTS.md` | symlinks | recreated per-host by `install.sh` from `$REPO` (so the target is host-correct) |

## Write-direction rule (one writer)

Edit the **source** only:
- shared agent context → `claude/CLAUDE.md` in this repo (or a designated `~/Vaults` note it `@import`s);
- MCP config → `context-sync/mcp.json.template` (tokens, never absolute paths).

**Never** edit a generated/linked file through its link: not the rendered
`$PROJECTS_ROOT/.mcp.json`, not `~/.codex/AGENTS.md` (it's a symlink to the home
loader). The Mac is the single writer; other hosts treat the rendered context as
read-only to avoid sync conflicts. Transport is git — `git pull` on a peer, then
re-run `install.sh`.

## Vault-as-context (opt-in)

The home loader can `@import` designated Obsidian notes via portable `~/Vaults/...`
paths — see the "Vault-as-context imports" section in `claude/CLAUDE.md`. `~`
expands per host, so one committed line works everywhere. Imports flow to Codex
automatically via the `~/.codex/AGENTS.md` symlink.

## `make doctor` — validator exit codes

`doctor.sh` reports all findings and exits with a distinct code per failure class:

| Code | Meaning |
|---|---|
| 0 | all green |
| 10 | broken symlink (managed home symlink target missing) |
| 11 | missing `@import` target referenced by the router |
| 12 | host-specific absolute path literal leaked into a committed file |
| 13 | `~/Vaults` referenced by the router but absent on this host |
| 14 | workspace present but `.mcp.json` never rendered (run `render-mcp.sh`) |

## Recovery

- Context broke after a host move → re-run `bash install.sh` (idempotent).
- Diagnose → `make doctor` (the exit code names the failure class).
- Re-render `.mcp.json` only → `bash context-sync/render-mcp.sh`
  (or `PROJECTS_ROOT=/path bash context-sync/render-mcp.sh`).
