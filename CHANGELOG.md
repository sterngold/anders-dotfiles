# Changelog

All notable changes to this project will be documented in this file.

This file is maintained automatically by [release-please](https://github.com/googleapis/release-please)
based on [Conventional Commits](https://www.conventionalcommits.org/). Do not edit manually.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning: [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.18.0](https://github.com/sterngold/anders-dotfiles/compare/v1.17.1...v1.18.0) (2026-07-05)


### Features

* **AND-1773:** codex-dispatch dep provisioning + stale-reuse heal ([#47](https://github.com/sterngold/anders-dotfiles/issues/47)) ([3530235](https://github.com/sterngold/anders-dotfiles/commit/35302354f8e6ac02739ebb0def52a4f2ca68d027))

## [1.17.1](https://github.com/sterngold/anders-dotfiles/compare/v1.17.0...v1.17.1) (2026-07-04)


### Bug Fixes

* document aggregate ci gate ([50c0cae](https://github.com/sterngold/anders-dotfiles/commit/50c0cae0808524cd757a22e886ebb0d116dc62c2))
* document aggregate ci gate ([#45](https://github.com/sterngold/anders-dotfiles/issues/45)) ([50c0cae](https://github.com/sterngold/anders-dotfiles/commit/50c0cae0808524cd757a22e886ebb0d116dc62c2))

## [1.17.0](https://github.com/sterngold/anders-dotfiles/compare/v1.16.0...v1.17.0) (2026-07-03)


### Features

* **sandbox:** exclude anders-build from the seatbelt so ralph's nested claude escapes (AND-1749) ([c112f84](https://github.com/sterngold/anders-dotfiles/commit/c112f840d34385fcae0a3bcbd600629db6d3ba7e))

## [1.16.0](https://github.com/sterngold/anders-dotfiles/compare/v1.15.1...v1.16.0) (2026-07-03)


### Features

* **policy:** exclude ssh from the sandbox on all machines ([c5ee718](https://github.com/sterngold/anders-dotfiles/commit/c5ee718e4c6c5ccb29f784153be155dbdd71a832))
* **policy:** whitelisted-sessions hardening — allowlist single-source + hook parity + session badge ([a39562a](https://github.com/sterngold/anders-dotfiles/commit/a39562a523513e27890be92d9d896e85e2f99954))


### Bug Fixes

* **AND-1680:** guard codex-dispatch dirty sources ([#43](https://github.com/sterngold/anders-dotfiles/issues/43)) ([3ecf538](https://github.com/sterngold/anders-dotfiles/commit/3ecf5383cb57d60abeba7e95e0ca5a0d3c82ebbc))

## [1.15.1](https://github.com/sterngold/anders-dotfiles/compare/v1.15.0...v1.15.1) (2026-06-29)


### Bug Fixes

* **cc:** move submodule core.worktree to per-worktree config + add cc --repair ([ac677a9](https://github.com/sterngold/anders-dotfiles/commit/ac677a985bba283d6a20a52849990be05ba12c40))
* **codex:** write codex -o file outside the worktree ([#40](https://github.com/sterngold/anders-dotfiles/issues/40)) ([bbcde03](https://github.com/sterngold/anders-dotfiles/commit/bbcde035c53935959088eae97d12c4f7377fa651))

## [1.15.0](https://github.com/sterngold/anders-dotfiles/compare/v1.14.1...v1.15.0) (2026-06-29)


### Features

* **codex:** worktree-isolated headless Codex dispatch primitive ([#38](https://github.com/sterngold/anders-dotfiles/issues/38)) ([a9abe67](https://github.com/sterngold/anders-dotfiles/commit/a9abe67fcfc93927a39cc2d9ae99a6995f99ae4e))

## [1.14.1](https://github.com/sterngold/anders-dotfiles/compare/v1.14.0...v1.14.1) (2026-06-28)


### Bug Fixes

* **cc:** submodule-root projects worktree the submodule itself + loud broken-git warning ([7b097e5](https://github.com/sterngold/anders-dotfiles/commit/7b097e5472be22be9b14d69493a87ed6f9133da6))

## [1.14.0](https://github.com/sterngold/anders-dotfiles/compare/v1.13.0...v1.14.0) (2026-06-28)


### Features

* **policy:** exclude ollama CLI from sandbox (loopback unreachable in-sandbox) ([4b1eb7c](https://github.com/sterngold/anders-dotfiles/commit/4b1eb7c5348cd0b68d5fff7b9177446d0585f221))


### Bug Fixes

* **babystar:** double-wide stripes + travel marker for unmistakable design ([dc4ada6](https://github.com/sterngold/anders-dotfiles/commit/dc4ada69ae40137a52f0fa443e1096eefb0bd626))
* **babystar:** fix double banner + make BabyStar header more striking ([9c57045](https://github.com/sterngold/anders-dotfiles/commit/9c5704582c3bd47eb72b9dfce4b4823c4260b317))

## [1.13.0](https://github.com/sterngold/anders-dotfiles/compare/v1.12.1...v1.13.0) (2026-06-28)


### Features

* **cc:** add cc-health vault shortcut mirroring cc-finance ([0b3aad1](https://github.com/sterngold/anders-dotfiles/commit/0b3aad192a9d946f719ee655be1780cf644764ae))
* **policy:** managed-settings floor template + installer + HTTPS-canonical git transport ([441d386](https://github.com/sterngold/anders-dotfiles/commit/441d38639aaa08a684e364a73894d1c4056912ac))
* **policy:** single-source sandbox allowedDomains from egress-allowlist + unblock localhost ([72cbc36](https://github.com/sterngold/anders-dotfiles/commit/72cbc360d106f10d61bcd66eb1569e8a7860e8ca))
* **zsh:** per-machine identity banner (host-banner.zsh) ([773a35d](https://github.com/sterngold/anders-dotfiles/commit/773a35d51f6e6808eebb598cc171146097ec4026))


### Bug Fixes

* **policy:** nest disableBypassPermissionsMode under permissions ([82fccfe](https://github.com/sterngold/anders-dotfiles/commit/82fccfe7878b487493c9a56d60fdb38e44ef1725))
* **zsh:** lowercase hostname in host-banner so BabyStar matches any casing ([823195e](https://github.com/sterngold/anders-dotfiles/commit/823195e5c37cf0e52194644a3c8b5281c229645e))

## [1.12.1](https://github.com/sterngold/anders-dotfiles/compare/v1.12.0...v1.12.1) (2026-06-22)


### Bug Fixes

* **host-portability:** make html-hub paths ~/-relative in claude/CLAUDE.md (was leaked absolute literal, doctor exit 12) ([a2f7860](https://github.com/sterngold/anders-dotfiles/commit/a2f78607e47fd7eed90f812d990ddd6c0f166c7f))

## [1.12.0](https://github.com/sterngold/anders-dotfiles/compare/v1.11.1...v1.12.0) (2026-06-06)


### Features

* **zsh:** codexwt — isolated build-ready worktree for cross-agent handoff ([bde4fe9](https://github.com/sterngold/anders-dotfiles/commit/bde4fe9b250b812817ffec355bcb7388e8a5510e))

## [1.11.1](https://github.com/sterngold/anders-dotfiles/compare/v1.11.0...v1.11.1) (2026-06-06)


### Bug Fixes

* **github-mcp:** resolve gh by absolute path in .zshenv (PATH not ready yet) ([2ccc44d](https://github.com/sterngold/anders-dotfiles/commit/2ccc44dbae6026c206c135ec69339a73096b8efb))

## [1.11.0](https://github.com/sterngold/anders-dotfiles/compare/v1.10.0...v1.11.0) (2026-06-05)


### Features

* add atlas() helper to regenerate + open the Process Atlas ([188393c](https://github.com/sterngold/anders-dotfiles/commit/188393c09982132c4339b23c45f00e11bda91c86))


### Bug Fixes

* **ralph:** worktree-aware allowlist — permit allowlisted projects in .claude/worktrees ([ca5bfef](https://github.com/sterngold/anders-dotfiles/commit/ca5bfef1c3139b0a947fe0e388a000356a444b1a))

## [1.10.0](https://github.com/sterngold/anders-dotfiles/compare/v1.9.0...v1.10.0) (2026-06-03)


### Features

* **zsh:** GitHub MCP token via ~/.zshenv + launchd-safe claude-mcp wrapper ([e6055bd](https://github.com/sterngold/anders-dotfiles/commit/e6055bd0c3558f8643cbb16b20c3e5a6dbb8fde9))

## [1.9.0](https://github.com/sterngold/anders-dotfiles/compare/v1.8.1...v1.9.0) (2026-06-02)


### Features

* **cc:** add `ccdoctor` alias for the resolver invariant check ([9ba8bc6](https://github.com/sterngold/anders-dotfiles/commit/9ba8bc6da03983ad8c98d924a1e042f8c2ac771b))
* **cc:** suggest closest project on a miss ("did you mean: KnowledgeBase?") ([aaf2b10](https://github.com/sterngold/anders-dotfiles/commit/aaf2b10d7715ddd08d9015621c11a9828e8062ca))
* **doctor:** cc-resolvability invariant check (catches collisions/unreachable) ([8ca1e74](https://github.com/sterngold/anders-dotfiles/commit/8ca1e74cc959bf6b987e9be3cf187cb0dea066bf))


### Bug Fixes

* **cc:** address PR review — crash≠miss classification + category-list drift ([cba8057](https://github.com/sterngold/anders-dotfiles/commit/cba80571586b16a02660aac9b5999dad0c285311))

## [1.8.1](https://github.com/sterngold/anders-dotfiles/compare/v1.8.0...v1.8.1) (2026-06-02)


### Bug Fixes

* **cc:** drop 90_ARCHIVE from category scan so archives don't shadow active projects ([d4f867a](https://github.com/sterngold/anders-dotfiles/commit/d4f867a219a85626c1671e2562a69f48bced1ae0))

## [1.8.0](https://github.com/sterngold/anders-dotfiles/compare/v1.7.0...v1.8.0) (2026-06-02)


### Features

* **cc:** worktree freshness check on reuse + --new for parallel worktrees ([e7026e7](https://github.com/sterngold/anders-dotfiles/commit/e7026e7996b81e47b0bff206516ee824e85ad04b))

## [1.7.0](https://github.com/sterngold/anders-dotfiles/compare/v1.6.1...v1.7.0) (2026-06-02)


### Features

* **zsh:** portable terminal stack — Brewfile + starship/atuin configs + terminal-stack.zsh ([1686fd6](https://github.com/sterngold/anders-dotfiles/commit/1686fd642a533b3bc6d6d9149e06a36d17fd5dcb))


### Bug Fixes

* **ralph/AND-1345:** repair bit-rot — active-profile allowlist + run-entry prune count ([#21](https://github.com/sterngold/anders-dotfiles/issues/21)) ([eb409c6](https://github.com/sterngold/anders-dotfiles/commit/eb409c6b094712e3b50b4e53220b27d66742ee06))

## [1.6.1](https://github.com/sterngold/anders-dotfiles/compare/v1.6.0...v1.6.1) (2026-06-01)


### Bug Fixes

* **cc:** true-default worktree base, bare-cc hint, configurable project roots ([#19](https://github.com/sterngold/anders-dotfiles/issues/19)) ([6eac378](https://github.com/sterngold/anders-dotfiles/commit/6eac3786b72e55d3ab6f7865b9437529769ea907))

## [1.6.0](https://github.com/sterngold/anders-dotfiles/compare/v1.5.0...v1.6.0) (2026-05-31)


### Features

* **context-sync:** AGENTS.md assembly machinery — agents-canon.md + assemble-agents.sh (AND-1295) ([d437c2b](https://github.com/sterngold/anders-dotfiles/commit/d437c2bbf5c3b2446bc01087ba6191d26c987b85))
* **context-sync:** flip canonical direction CLAUDE.md -&gt; AGENTS.md ([b90ed26](https://github.com/sterngold/anders-dotfiles/commit/b90ed2614c03a90f42f8d6bf711fa713d04367df))
* **context-sync:** optional AGENTS.body.md slot in assemble-agents.sh (AND-1298) ([f46795f](https://github.com/sterngold/anders-dotfiles/commit/f46795f47ef655bce300fcd003d8fe0d8453477b))

## [1.5.0](https://github.com/sterngold/anders-dotfiles/compare/v1.4.0...v1.5.0) (2026-05-31)


### Features

* **context-sync:** stage render-claude.sh for AGENTS.md-canonical flip ([3e78e21](https://github.com/sterngold/anders-dotfiles/commit/3e78e2118c2a9ec9809dad356cf1aaa12b156d17))

## [1.4.0](https://github.com/sterngold/anders-dotfiles/compare/v1.3.0...v1.4.0) (2026-05-29)


### Features

* **claude:** add Working lens for the Constitution's Orientation ([41b869e](https://github.com/sterngold/anders-dotfiles/commit/41b869e24674b5eab1e6513b64f3cad3f882fa25))
* **doctor:** add --json emitter to context-sync/doctor.sh ([3203903](https://github.com/sterngold/anders-dotfiles/commit/320390336411a7435932bb59b5059a6b5fba2656))


### Bug Fixes

* **doctor:** keep --json stdout-pure + escape control chars in summaries ([2dfe184](https://github.com/sterngold/anders-dotfiles/commit/2dfe184e671355f6a78d275efbc60ee03685c274))

## [1.3.0](https://github.com/sterngold/anders-dotfiles/compare/v1.2.0...v1.3.0) (2026-05-29)


### Features

* **context-sync:** render-agents.sh — generate AGENTS.md from CLAUDE.md + addendum ([07a1c49](https://github.com/sterngold/anders-dotfiles/commit/07a1c49652516d56855c2abdd6f0725feaa75017))


### Bug Fixes

* **context-sync:** render-agents --check distinguishes stale from error ([f4d1230](https://github.com/sterngold/anders-dotfiles/commit/f4d1230005b04eabb8dc8b6bb83ad7064614ade2))
* **context-sync:** render-agents.sh chmod 644 the output ([921aa3e](https://github.com/sterngold/anders-dotfiles/commit/921aa3e6904cfcc72d49e2197d6f085dc9e774e0))

## [1.2.0](https://github.com/sterngold/anders-dotfiles/compare/v1.1.0...v1.2.0) (2026-05-29)


### Features

* portable AI-context foundation (render .mcp.json, doctor, vault hook) ([#11](https://github.com/sterngold/anders-dotfiles/issues/11)) ([1650e01](https://github.com/sterngold/anders-dotfiles/commit/1650e01f07e034a88f3c300b93237dba5246ed90))


### Bug Fixes

* **context-sync:** harden doctor + render per PR review ([#13](https://github.com/sterngold/anders-dotfiles/issues/13)) ([0af1883](https://github.com/sterngold/anders-dotfiles/commit/0af18834650f955ba1aa2b3dbbdd626272d30d13))
* **render-mcp:** announce when JSON validation is skipped ([#14](https://github.com/sterngold/anders-dotfiles/issues/14)) ([87ca1e7](https://github.com/sterngold/anders-dotfiles/commit/87ca1e7aafc66285e7074c2bb8219d4a2ddd900c))

## [1.1.0](https://github.com/sterngold/anders-dotfiles/compare/v1.0.0...v1.1.0) (2026-05-27)


### Features

* per-project .no-worktree marker file support in cc ([25cf505](https://github.com/sterngold/anders-dotfiles/commit/25cf50524d9af7ff2d84b43e4cb4221387d5b00a))

## 1.0.0 (2026-05-17)


### Features

* add git-clean alias for all-repo pristine check ([994d6a6](https://github.com/sterngold/anders-dotfiles/commit/994d6a6bb06325fb5377e8a3678eb33080cd8360))
* **cc:** add --add-dir ~/Vaults to all cc wrappers for cross-boundary Vault access ([61c9bdd](https://github.com/sterngold/anders-dotfiles/commit/61c9bddffa291e3ab8574113272296f02223c670))
* **zsh:** cc-finance launcher for VladFinance vault ([2af2976](https://github.com/sterngold/anders-dotfiles/commit/2af2976a38fab05832c65f58753adde969321162))


### Bug Fixes

* **claude-usage:** patch upstream cutoff ReferenceError + idempotent applier ([a36efe0](https://github.com/sterngold/anders-dotfiles/commit/a36efe01ea98d5358f098299e0010498cae8a4a3))
* **claude-usage:** preserve cc-build + cc-full data across dashboard rescan ([d52339f](https://github.com/sterngold/anders-dotfiles/commit/d52339fed0bf05cc76eec67cbfa2ae422e50a6ea))
* **commitlint:** unblock Dependabot/release-please PRs ([#5](https://github.com/sterngold/anders-dotfiles/issues/5)) ([5bec4f8](https://github.com/sterngold/anders-dotfiles/commit/5bec4f819a0b8e52d8c32f9881e03ca7b478b80f))
* correct PROJECTS_ROOT path assumption — AndersStar uses ~/Code/my-projects ([12c45fb](https://github.com/sterngold/anders-dotfiles/commit/12c45fbcf3aef63ef943301d9196728c8fabd105))
* don't blanket-symlink cc-build/cc-partner skills ([0fe40f6](https://github.com/sterngold/anders-dotfiles/commit/0fe40f6b983ac73cadd5120e99a91fc31d5d9595))
* permissions — close wildcard exploits, tighten deny list ([91c6c29](https://github.com/sterngold/anders-dotfiles/commit/91c6c29ecc54286b0311def81c12c253bfba1a51))

## [Unreleased]
