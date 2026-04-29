# anders-dotfiles

Claude Code configuration across machines. Four modes, three machines, one source of truth.

## What's versioned

| Path | Role |
|---|---|
| `claude/settings.json` | Default `claude` — daily driver base |
| `claude/CLAUDE.md` | Global context loader (points to Constitution) |
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
- `~/.claude/skills/` — symlinks to `anders-config/skills/` (versioned there)

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
- BabyStar (travel): `PROJECTS_ROOT=~/Desktop/GoogleDrive/My_projects`

`settings.json` hooks and `statusline.sh` use `${PROJECTS_ROOT}` — add it to `~/.zprofile` on any new machine before installing.

## Updating

Edit files in this repo, commit, push. On other machines: `git pull && ./install.sh` (no-op if symlinks already correct).

Per `anders-config/rules/git-discipline.md`: one concern per commit, message = why not what.
