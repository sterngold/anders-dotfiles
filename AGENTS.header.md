## 1. Repo identity

- **Repo:** `anders-dotfiles`
- **Purpose:** host-portable dotfiles + the shared AI-agent context layer (home `CLAUDE.md`/`AGENTS.md`, `.mcp.json` render, Codex parity, security/way-of-working rules) — edit once on the writer host, any peer becomes a full peer with one idempotent run.
- **Owner:** @sterngold
- **Status:** active
- **Stack:** Shell (bash) · `make` · git — no compiled application.

---

## 2. Build, test, lint

This repo is shell + config, not a compiled app. The polyglot `Makefile` targets exist for uniformity but mostly no-op here (no `pyproject.toml` / `package.json` / `Package.swift`). The **real** verification is:

```bash
# Install / re-sync this host (idempotent — creates symlinks, renders .mcp.json)
bash install.sh

# Validate the context layer (exit code names the failure class — see context-sync/README.md)
bash context-sync/doctor.sh

# Assemble this repo's AGENTS.md from header + shared canon (this file's own machinery)
bash context-sync/assemble-agents.sh --check .   # 0 ok · 1 stale · 2 error

# Lint the shell scripts
shellcheck install.sh context-sync/*.sh

# Generic Makefile passthroughs (no-op unless a language manifest is added)
make test
make lint
```

**Agents:** if `make <target>` does not exist or no-ops, run the underlying command above. Do not invent commands.
