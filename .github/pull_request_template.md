## Summary

<!-- One paragraph: what changed and why. Link the motivation, not just the diff. -->

## Type of Change

<!-- Check all that apply -->

- [ ] Bug fix (non-breaking change that fixes an issue)
- [ ] New feature (non-breaking change that adds functionality)
- [ ] Breaking change (fix or feature that changes existing behavior)
- [ ] Refactor (no behavior change, improves structure or readability)
- [ ] Chore (dependency update, config, CI, tooling)
- [ ] Docs

## Related Issues

<!-- Closes #<issue>, Fixes #<issue>, or N/A -->

Closes #

## Changes

<!-- Bullet list of what was added, changed, or removed. Be specific. -->

- 
- 

## Testing

<!-- Describe what you tested and how. Screenshots/recordings for UI changes. -->

**Manual steps to verify:**

1. 
2. 

**Test coverage:**

- [ ] Unit tests added / updated
- [ ] Widget tests added / updated
- [ ] Tested on Android
- [ ] Tested on Web

## Security & Privacy Checklist

<!-- Required for any PR touching auth, Firestore rules, RTDB, or Cloud Functions -->

- [ ] No secrets or API keys added to tracked files
- [ ] Firestore / RTDB security rules updated (if applicable)
- [ ] Chat messages are not persisted beyond session end (Privacy by Design)
- [ ] No Firebase SDK calls outside `datasources/`

## Clean Architecture Checklist

- [ ] Domain layer has zero Flutter / Firebase imports
- [ ] Business logic lives in UseCases, not Notifiers or Screens
- [ ] New `@freezed` models ran through `build_runner` (no hand-rolled `fromJson`)
- [ ] No unbounded `ListView` with `children: [...]` for dynamic data

## Screenshots / Recordings

<!-- UI changes: before/after screenshots or a short screen recording. Delete if not applicable. -->

| Before | After |
|--------|-------|
|        |       |

## Notes for Reviewers

<!-- Anything the reviewer should know: gotchas, follow-up tickets, intentional trade-offs. -->
