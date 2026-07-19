# AGENTS.md

Conventions for **every** human and AI agent working in this repo.
Model-agnostic by design — read once, applies whether you're Claude Code, Codex, Cursor, Aider, Gemini, Continue, Cline, or a human.

This file is the **single source of truth** for repo conventions.
`CLAUDE.md`, `.cursorrules`, `.aider.conf.yml` are pointers — do not duplicate content into them.

<!-- ASSEMBLED — DO NOT EDIT AGENTS.md DIRECTLY.
     Per-repo header (§1–2) = this repo's AGENTS.header.md (hand-edited, repo-specific).
     Shared canon (§3–13)  = anders-dotfiles/context-sync/agents-canon.md (ONE source, all repos).
     Regenerate:  bash <dotfiles>/context-sync/assemble-agents.sh <repo-dir>
     Drift-check: bash <dotfiles>/context-sync/assemble-agents.sh --check <repo-dir>  (0 ok · 1 stale · 2 err) -->

---

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

---

## 3. Commit messages — Conventional Commits 1.0

Format: `<type>(<scope>): <subject>`

| Type | When |
|---|---|
| `feat` | New user-facing capability |
| `fix` | Bug fix |
| `refactor` | Code change, no behaviour change |
| `perf` | Performance |
| `docs` | Docs only |
| `test` | Tests only |
| `chore` | Tooling, deps, config |
| `ci` | CI/CD only |
| `revert` | Revert prior commit |

**Scope** = ticket ID when available (Linear/Jira/GitHub issue).

✅ `feat(AND-1146): add prompt route normalization`
✅ `fix: handle empty payload in /api/chat`
✅ `chore(deps): bump ruff to 0.6.9`
❌ `update stuff`
❌ `WIP`
❌ `clip: Staff Engineer. (retry)`

Breaking changes: append `!` and add `BREAKING CHANGE:` footer.
`feat(api)!: drop /v1 endpoints`

---

## 4. Branch naming

Format: `<type>/<TICKET>-<kebab-slug>`

`<type>` = same as commit types (`feat`, `fix`, `chore`, `docs`, `refactor`, `test`, `ci`).
`<TICKET>` = ticket ID in UPPER-CASE, or omit if no ticket.
`<kebab-slug>` ≤ 50 chars, lowercase, hyphens.

✅ `feat/AND-1146-prompt-normalize`
✅ `fix/AND-1150-empty-payload-crash`
✅ `chore/bump-ruff`
❌ `vsterngold/and-1146` (no username prefix)
❌ `chore/169ea4-anders-config-env` (no commit hashes)
❌ `codex/foo` (no agent-name prefix — agent identity is in commit trailer, not branch)

**Agent attribution** lives in commit trailers, not branch names:
```
Co-authored-by: Claude <noreply@anthropic.com>
```

---

## 5. Pull requests

- **All changes** to `main` go through a PR. No direct pushes.
- PR title MUST follow Conventional Commits (CI enforces).
- PR description MUST fill the template (`.github/pull_request_template.md`).
- **Squash-merge only.** Linear history required.
- Required passing check: `ci` — the aggregate job in `.github/workflows/ci.yml` that gates commit convention, secret scan, and any repo-specific blocking backstops. Python/Node lint+test jobs may be advisory when configured with `continue-on-error: true`; skipped stack-conditional jobs are allowed, and making them blocking requires changing the workflow first.
- Solo flow: 0 required human reviewers. CodeRabbit / Copilot Review = required reviewer.

---

## 6. Versioning & releases

- **SemVer 2.0.** `MAJOR.MINOR.PATCH`.
- Releases managed by [release-please](https://github.com/googleapis/release-please) — opens a release PR that bumps version + updates `CHANGELOG.md` from Conventional Commits.
- Tags: `v<MAJOR>.<MINOR>.<PATCH>` (e.g. `v1.4.2`).
- Pre-1.0 repos: breaking changes allowed in `MINOR` per SemVer §4.

---

## 7. Secrets & sensitive data

- **Never** commit secrets, API keys, tokens, `.env` files, credentials.
- `gitleaks` runs pre-commit AND in CI. Both must pass.
- `.env` is gitignored. Use `.env.example` for templates.
- For vault repos (medical, financial, personal): hybrid pattern — text tracked, blobs in `.gitignore` under `vault/blobs/`.
- If a secret leaks: rotate first, then `git filter-repo` to scrub history, then force-push (one of the few times force-push is allowed — to a non-protected branch).

---

## 8. Signed commits

All commits MUST be signed (SSH or GPG). CI verifies. Setup:

```bash
git config --global gpg.format ssh
git config --global user.signingkey ~/.ssh/id_ed25519.pub
git config --global commit.gpgsign true
git config --global tag.gpgsign true
```
Then add the same SSH key as a **Signing Key** in GitHub → Settings → SSH and GPG keys.

---

## 9. Code style

- `.editorconfig` is canonical for indent, EOL, charset, final newline.
- Language-specific formatters configured per repo (ruff/black for Python, prettier for JS/TS, swift-format for Swift).
- Pre-commit runs them. Do not bypass with `--no-verify` unless you are unblocking a hot fix and will follow up with a `chore: re-apply formatter` PR.

---

## 10. Dependencies

- **Python:** `uv` for env + lockfile. `pyproject.toml` is source of truth.
- **JS/TS:** `npm` or `pnpm`. Lockfile committed.
- **Swift:** SwiftPM. `Package.resolved` committed.
- Dependabot runs weekly, groups patch + minor PRs.

---

## 11. Documentation expectations

Repos must contain:
- `README.md` — what it is, how to run it, how to test it
- `AGENTS.md` — this file
- `CHANGELOG.md` — auto-maintained by release-please
- `docs/` — design notes, ADRs (Architecture Decision Records) for non-trivial choices

ADR format: `docs/adr/NNNN-short-title.md`. One per decision. Date + context + decision + consequences.

---

## 12. Working with AI agents in this repo

**For the agent reading this:** these rules apply to YOU.

- Read this file in full before making changes.
- Follow Section 3 (commit format) and Section 4 (branch naming) exactly.
- Run the repository-specific **pre-PR validation** commands declared in Section 2 before opening a PR. Setup/install commands and operations explicitly labeled owner-only, live, preview, deploy, or publish are not pre-PR agent gates; never run them without the required context and approval. Never invent a generic `make` target or substitute a weaker command.
- Never commit secrets. Never bypass pre-commit hooks.
- Sign commits if possible; otherwise note in PR description so the human can amend.
- Add yourself as co-author trailer.
- If this file is unclear or contradicts another instruction, ask in the PR description rather than guessing.

**For the human:** treat AI commits the same as human commits — they pass the same gates or they don't merge.

---

## 13. Anti-patterns (don't do this)

| ❌ | ✅ |
|---|---|
| Force-push to `main` | Open a PR. Force-push only on your own feature branch. |
| `git commit --no-verify` | Fix the hook violation. |
| Direct commit to `main` | PR + squash-merge. |
| `update README` as a commit | `docs: clarify install steps` |
| Branch named after yourself or your tool | Branch named after the work (`feat/AND-1234-…`) |
| Storing secrets in `config.py` "just for now" | `.env` + `python-decouple` / `os.getenv`. |
| Manual CHANGELOG edits | release-please owns CHANGELOG. |
