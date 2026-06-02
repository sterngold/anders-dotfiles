# Changelog

All notable changes to this project will be documented in this file.

This file is maintained automatically by [release-please](https://github.com/googleapis/release-please)
based on [Conventional Commits](https://www.conventionalcommits.org/). Do not edit manually.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning: [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
