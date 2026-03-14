---
name: ship
description: Use when ready to merge a PR and deploy a new version of open-wispr - handles version bump, merge, and deploy
---

# Ship

Merge a PR and deploy a new release of open-wispr.

## Prerequisites

- On a feature branch with an open PR
- All CI checks passing

## Workflow

### Step 1: Verify PR is ready

```bash
gh pr checks $(gh pr view --json number --jq '.number')
```

All checks must pass. If any are failing, stop and tell the user.

### Step 2: Bump minor version if needed

Read `Sources/OpenWisprLib/Version.swift` and parse the current version (`MAJOR.MINOR.PATCH`).

Increment the minor version by 1 and reset patch to 0 (e.g., `0.25.0` -> `0.26.0`).

Check recent commits on the current branch - if a version bump commit already exists, skip this step.

If bumping:
1. Update the version string in `Version.swift`
2. Commit and push:
   ```bash
   fgit "v<NEW_VERSION>"
   ```

### Step 3: Merge the PR

```bash
gh pr merge --squash --delete-branch
```

### Step 4: Switch to main and pull

```bash
git checkout main && git pull origin main
```

### Step 5: Deploy

The deploy script calls `claude -p` for release notes, which fails inside a Claude Code session due to nesting detection. Unset `CLAUDECODE` to fix this:

```bash
env -u CLAUDECODE bash scripts/deploy.sh <NEW_VERSION>
```

This runs the full deploy pipeline: build, tag, push, update tap, create GitHub release, and wait for bottle builds.

## Important

- Never deploy without all PR checks green
- Never skip the version bump
- Always use `env -u CLAUDECODE` when running the deploy script
