## 1. Repo identity

- **Repo:** `anders-dotfiles`
- **Purpose:** host-portable dotfiles + the shared AI-agent context layer (home `CLAUDE.md`/`AGENTS.md`, `.mcp.json` render, Codex parity, security/way-of-working rules) — edit once on the writer host, any peer becomes a full peer with one idempotent run.
- **Owner:** @sterngold
- **Status:** active
- **Stack:** Shell (bash) · `make` · git — no compiled application.

---

## 2. Build, test, lint

This repo is shell + config, not a compiled app. The polyglot `Makefile` targets exist for uniformity but mostly no-op here (no `pyproject.toml` / `package.json` / `Package.swift`). The **real** verification is:

**Pre-PR validation:**

```bash
bash context-sync/assemble-agents.sh --check .
git ls-files -z '*.sh' | xargs -0 shellcheck -S warning
make test
git diff --check
```

**Owner-only host integration (not a pre-PR agent gate):**

```bash
bash install.sh                 # mutates host symlinks and rendered settings
bash context-sync/doctor.sh     # validates the installed host plus the live fleet
```

**Agents:** if `make <target>` does not exist or no-ops, run the underlying command above. Do not invent commands.
