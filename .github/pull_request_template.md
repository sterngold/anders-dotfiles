<!--
Title MUST follow Conventional Commits.
✅ feat(AND-1146): add prompt route normalization
❌ Update prompt logic
-->

## Summary

<!-- 1–3 sentences: what changed and why -->

## Ticket

<!-- e.g. AND-1146, or "no ticket" -->

## Test plan

<!-- Commands run + what you verified. Be specific. -->
- [ ] `make lint` passes
- [ ] `make test` passes
- [ ] Manual check: …

## Risk

<!-- What could break? Migrations? Breaking changes? Rollback plan? -->

## Screenshots / logs

<!-- Optional but encouraged for UI or behaviour changes -->

## Checklist

- [ ] Conventional Commit title
- [ ] Branch follows `<type>/<TICKET>-<slug>`
- [ ] No secrets committed (gitleaks passed)
- [ ] CHANGELOG handled by release-please (do not edit manually)
- [ ] If breaking change: `BREAKING CHANGE:` footer in a commit
