# Changelog

All notable changes to this project will be documented in this file.

This file is maintained automatically by [release-please](https://github.com/googleapis/release-please)
based on [Conventional Commits](https://www.conventionalcommits.org/). Do not edit manually.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning: [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
