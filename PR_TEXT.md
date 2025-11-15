# PR: Docs & Release Prep (v1.2.14)

## What
- Add unified docs (`developer-utilities.md`, `ci-cd.md`, `release-process.md`, `readme-consistency.md`).
- Update `CHANGELOG.md` with v1.2.14 entry.

## Why
- Single source of truth between `jutellane-main` and `jutellane-blogs`.
- Predictable release via `Cut-Release.ps1`.

## Test
- Render docs locally and check links.
- Run dry-run: `./scripts/Cut-Release.ps1 -Version 1.2.14 -DryRun -Verbose`.

## After merge
- Execute: `./scripts/Cut-Release.ps1 -Version 1.2.14 -Verbose`.

