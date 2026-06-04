# AGENTS.md-canonical — Status & Queue (single source of truth)

> **This file is the canonical status for the AGENTS.md-canonical standardization.**
> It supersedes the two plan files (`~/.claude-full/plans/read-this-in-downloads-tender-gosling.md`,
> `~/.claude-full/plans/plan-and-propose-cadance-starry-dawn.md`) and the standardization
> section of `~/Code/my-projects/HANDOVER.md`. When state changes, update **here**.
> Linear project: **Anders9 / Git / Agent-Tooling Standardization (AGENTS.md-canonical)**.

## What "done" means (4 conditions — all required)

A repo is converted iff:
1. `AGENTS.header.md` exists (§1–2: repo identity + build/test/lint, repo-specific).
2. `AGENTS.md` is **assembled** from header + central canon (`agents-canon.md` §3–13) + optional `AGENTS.body.md`.
3. `CLAUDE.md` is a **thin pointer** (≤~12 lines, `@AGENTS.md`; add `@HANDOVER.md` only where the repo has one).
4. `bash ~/anders-dotfiles/context-sync/assemble-agents.sh --check <repo>` exits **0**.

⚠️ **`completedAt` from a PR auto-close ≠ done.** GitHub→Linear closes an issue when a PR title carries its `AND-NNN`, even if the issue's scope is only half-shipped (this is how AND-1299 and AND-1298 went falsely-Done). Trust condition 4, not the Linear badge.

## Machinery (done)

- `agents-canon.md` — the shared §3–13 canon, ONE source for every repo.
- `assemble-agents.sh` — `<repo>` writes / `--check` verifies (0 sync · 1 stale · 2 no-header/error).
- Optional per-repo `AGENTS.body.md` — rich all-agent content (§14+) appended after the canon.
- `anders_doctor` §15 — asserts AGENTS.md present + CLAUDE.md has `@AGENTS.md`.

## Status — by GATE × STATE (retires the old A/B/C labels)

A/B/C described a repo's *starting* state and over-counted (Momentum/Nudge were in both "Class B" and "clients"). What matters for execution is the **gate** (what it takes to land a change) and the **state**.

| Repo | Location | Gate | State |
|---|---|---|---|
| anders-config | submodule | sibling-direct | ✅ done |
| anders-dotfiles | ~/ | sibling-direct | ✅ done |
| AndersMem | submodule | submodule-direct | ✅ done |
| FoodLog | submodule | submodule-direct | ✅ done |
| Anderson | submodule | submodule-PR (CI) | ✅ done |
| Momentum | submodule (client) | client-PR | ✅ done |
| ai-context | ~/Code | sibling-direct | ✅ done |
| AIShared (sterngold-ai-shared) | ~/ | sibling-direct | ✅ done |
| shared-skills | ~/.claude-full | sibling-direct | ✅ done |
| Nudge | submodule (client) | client-PR | ✅ done (PR #92, `c666627`; Option-C audience split — operator ctx → `AGENTS.body.md`; prettier-ignored) |
| **werkanders-os** | ~/Code (governed site) | governed-site | ⚠️ **anomaly — canonical but NOT on pipeline** (hand-written AGENTS.md via PR #13; no header; `--check` exits 2; §3–13 will drift) |
| the-symbiotic-mind | ~/Code (governed site) | governed-site | ✅ done (AND-1296, PR #25; from-scratch) |
| andersreality-website | ~/Code (governed site) | governed-site | ✅ done (AND-1296, PR #7; from-scratch) |
| golden-soviet-gallery | ~/Code (governed site) | governed-site | ✅ done (AND-1296, PR #3; from-scratch; `AGENTS.*` prettier-ignored before assembly) |
| vlad-sterngold-os | ~/Code (governed site) | governed-site | ✅ done (AND-1296, PR #12; migration — former CLAUDE.md → `AGENTS.body.md` §14) |
| seo-ops | ~/Code (ops repo) | governed-site | ✅ done (AND-1296, PR #9; migration — former CLAUDE.md → `AGENTS.body.md` §14, + `@HANDOVER.md`) |
| **my-projects (root)** | workspace root | root | 🟦 **intentional exception** — hand-written workspace canon, NOT assembled by design. Do not "fix" it. |

**Tally:** 15 done · 1 anomaly (werkanders, AND-1298) · 0 remaining · 1 intentional exception. **AND-1296 complete** — werkanders-os pipeline migration (AND-1298) is the only standardization item left.

## 🔴 Prettier landmine (read before any TS/React repo)

A repo whose pre-commit hook runs `prettier --write` on `*.md` (lint-staged) reformats the **assembled** `AGENTS.md`, diverging its raw inlined canon from `assemble-agents.sh` output → `--check` fails every commit. **Fix:** add `AGENTS.md` + `AGENTS.header.md` + `AGENTS.body.md` to the repo's `.prettierignore` **before** converting, then assemble. First hit: Momentum (PR #39 recovery). Also hit + resolved: **Nudge** (PR #92 — `.prettierignore` added before assembly; `node lint` CI green). Also hit + resolved: **golden-soviet-gallery** (AND-1296, PR #3 — `AGENTS.md`/`AGENTS.header.md`/`AGENTS.body.md` added to `.prettierignore` before assembly; eslint scopes `**/*.{ts,tsx}` only + no CI, so the assembled file is safe). Memory: `feedback_prettier_ignore_assembled_agents`.

## Go-forward queue (each its own gated session — NOT bulk)

| # | Work | Gate | Linear | Notes |
|---|---|---|---|---|
| ~~1~~ | ~~**Nudge**~~ | client-PR | AND-1299 ✅ **Done** | Shipped PR #92 (`c666627`). Operator ctx → `AGENTS.body.md` (Option C). Follow-ups split: AND-1349 (.env loader research), AND-1350 (scrub hook → `.pre-commit-config.yaml`). |
| 1 | **werkanders-os** | governed-site | AND-1298 (reopened) | **migration, not from-scratch** — derive header+body from its current AGENTS.md, re-assemble so §3–13 = central canon, `--check` 0 |
| ~~3~~ | ~~the-symbiotic-mind · andersreality-website~~ | governed-site | AND-1296 ✅ | **Done** — PR #25 / #7 merged |
| ~~4~~ | ~~**golden-soviet-gallery**~~ | governed-site | AND-1296 ✅ | **Done** — PR #3 merged (`.prettierignore`'d before assembly) |
| ~~5~~ | ~~vlad-sterngold-os · seo-ops~~ | governed-site | AND-1296 ✅ | **Done** — PR #12 / #9 merged. AND-1296 complete. |
| 6 | AND-1300 vault-remote guard · AND-1301 Obsidian | dotfiles / vault | AND-1300 / AND-1301 | 1301 blocked on Recovery-vault content-class + babystar M5↔Air sync decisions |

**Governed-site rule:** for any `~/Code` live site, read `~/Code/seo-ops/control.md` first; branch+PR; never autonomously touch DNS / GSC / GA4 / deploy.

## Per-session start ritual

`/deep-load <project>` → `git -C <repo> status --short` → read the repo's HANDOVER → convert → `assemble-agents.sh --check` exit 0 → commit per gate.
