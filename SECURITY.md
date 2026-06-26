# Security Policy

## Reporting a Vulnerability

Please do not open public issues for security problems in this dotfiles repo.
Use GitHub private vulnerability reporting if it is available, or email the
maintainer listed on the profile.

Include:

- A short description of the issue and affected file.
- Reproduction steps or a minimal proof of concept.
- Any local secrets, tokens, hostnames, or personal paths that may have been exposed.

## Local Secrets

This repo intentionally keeps machine secrets outside git. If a token, API key,
private path, or private vault import is accidentally committed, rotate the
secret first, then remove it from history if needed.
