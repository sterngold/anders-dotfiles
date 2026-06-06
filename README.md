# anders-dotfiles

Host-portable Claude Code and AI-agent configuration.

This repository keeps the House of Anders agent context layer reproducible across machines: shared `CLAUDE.md` / `AGENTS.md` context, MCP rendering, hook loaders, shell aliases, and validation scripts. It is public as an example of how I keep AI-agent workflows consistent without copying rules into every tool by hand.

## What's Versioned

| Path | Role |
|---|---|
| `claude/` | Default Claude Code configuration and global context loader |
| `claude-full/` | Full-context mode for deeper project work |
| `claude-build/` | Build/spec-focused mode |
| `claude-partner/` | Clean-room partner mode |
| `zsh/cc-aliases.zsh` | Project-opening aliases and worktree helpers |
| `context-sync/` | Context rendering, AGENTS assembly, and validation scripts |

## What's Not Versioned

- Per-machine session history and auto-memory.
- Plugin caches and local tool state.
- Machine-specific settings, secrets, and credentials.
- Private project contents.

## Install

```bash
cd ~
git clone git@github.com:sterngold/anders-dotfiles.git
cd anders-dotfiles
./install.sh
```

`install.sh` is idempotent: it creates or refreshes symlinks, renders local config, and leaves machine-specific state outside the repo.

## Verify

```bash
bash context-sync/doctor.sh
bash context-sync/assemble-agents.sh --check .
shellcheck install.sh context-sync/*.sh
```

The validator catches missing imports, unsafe context paths, stale generated files, and hook-loader drift before the config is reused elsewhere.

## Why This Exists

AI-agent work gets brittle when every tool has its own half-remembered prompt and local convention file. This repo keeps the context layer explicit, testable, and portable: one source of truth, multiple agent surfaces.
