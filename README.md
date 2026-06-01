# anders-dotfiles

Claude Code configuration across machines. Four modes, three machines, one source of truth.

## What's versioned

| Path | Role |
|---|---|
| `claude/settings.json` | Default `claude` — daily driver base |
| `claude/CLAUDE.md` | Global context loader (Constitution + RTK) — linked to both `.claude` and `.claude-full` |
| `claude/RTK.md` | RTK token-saver reference — linked to both `.claude` and `.claude-full` |
| `claude/statusline.sh` | Shared status line shell script |
| `claude/keybindings.json` | Keybindings |
| `claude-full/settings.json` | `cc` alias → `~/.claude-full/` — full mirror |
| `claude-build/settings.json` | `cc-build` alias → `~/.claude-build/` — coding/spec focus |
| `claude-partner/settings.json` | `cc-partner` alias → `~/.claude-partner/` — clean-room partner |
| `zsh/cc-aliases.zsh` | `cc` / `cc-build` / `cc-partner` shell aliases |

## What's NOT versioned

- `~/.claude*/projects/` — auto-memory, session history (per-machine)
- `~/.claude*/plugins/` — installed plugins (per-machine, cached from marketplaces)
- `~/.claude*/file-history/` — edit history (ephemeral)
- `~/.claude*/backups/` — internal state (ephemeral)
- `~/.claude*/settings.local.json` — machine-specific overrides (if you ever need per-machine differences)
- `~/.claude/skills/` — symlinks to `00_SYSTEM/anders-config/skills/` (versioned there)

## Install (new machine)

```bash
cd ~ && git clone git@github.com:sterngold/anders-dotfiles.git
cd anders-dotfiles && ./install.sh
```

`install.sh` is idempotent — safe to re-run after pulling updates.

## Machines

| Machine | Role | Notes |
|---|---|---|
| AndersStar (M5 Max 128GB) | Main / server | Arrives Apr 21, 2026 |
| BabyStar (M5 Air 16GB) | Personal extension | Current daily driver |
| Alex's M5 Air | Shared with brother | Different user possible — may need path templating |

## Path assumptions

Path assumptions are machine-specific via `PROJECTS_ROOT` (set in `~/.zprofile` per machine):
- AndersStar (primary): `PROJECTS_ROOT=~/Code/my-projects`
- BabyStar (travel): `PROJECTS_ROOT=~/Code/my-projects` (moved out of Google Drive 2026-05-09)

`settings.json` hooks and `statusline.sh` use `${PROJECTS_ROOT}` — add it to `~/.zprofile` on any new machine before installing.

`cc <name>` resolves projects under `$PROJECTS_ROOT` (workspace + categories) and, by
default, the parent dir (`~/Code` siblings). To let `cc` find projects that live elsewhere,
set a colon-separated `CC_PROJECT_ROOTS` in `~/.zprofile`:

```sh
export CC_PROJECT_ROOTS="$HOME/Code:$HOME/work:$HOME/clients"
```

Each entry is scanned for an exact (case-insensitive) name match. For a one-off in an
unlisted location, `cc /abs/path` or `cc ~/anywhere/proj` resolves the path directly.
Auto-worktrees base off each repo's true default branch (`origin/HEAD`), not local `main`.

## Updating

Edit files in this repo, commit, push. On other machines: `git pull && ./install.sh` (no-op if symlinks already correct).

Per `00_SYSTEM/anders-config/rules/git-discipline.md`: one concern per commit, message = why not what.
