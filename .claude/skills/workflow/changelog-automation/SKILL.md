---
name: changelog-automation
description: Generate changelogs from git history, commits, PRs, and releases following Keep a Changelog format. Use when preparing releases, documenting changes, or auto-generating CHANGELOG.md.
argument-hint: "Generate changelog for v2.0.0 from all commits since v1.9.0"
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
model: inherit
effort: low
department: workflow
references: []
---

# Changelog Automation

Generate structured changelogs from git history. No manual tracking.

## Format

Follow [Keep a Changelog](https://keepachangelog.com/):

```markdown
# Changelog

## [2.0.0] - 2026-02-26

### ⚠️ Breaking Changes
- Removed deprecated `legacyAuth()` endpoint (#45)

### Added
- User notification system with email and push channels (#38)
- Rate limiting middleware for all API routes (#41)

### Changed
- Upgraded React from 18 to 19 (#40)
- Improved error messages for validation failures (#42)

### Fixed
- Race condition in concurrent file uploads (#39)
- Memory leak in WebSocket connection handler (#43)

### Security
- Patched XSS vulnerability in markdown renderer (#44)
```

## Workflow

### Step 1: Determine Range

```bash
# From last tag to HEAD
LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
if [ -z "$LAST_TAG" ]; then
  RANGE="HEAD"
else
  RANGE="${LAST_TAG}..HEAD"
fi
echo "Generating changelog for: $RANGE"
```

### Step 2: Parse Commits

```bash
git log $RANGE --pretty=format:"%h|%s|%an" --no-merges
```

### Step 3: Categorize

Map conventional commit prefixes to changelog sections:

| Prefix | Section | Example |
|--------|---------|---------|
| `feat:` | Added | `feat: add notification system` |
| `fix:` | Fixed | `fix: race condition in uploads` |
| `perf:` | Changed | `perf: optimize query execution` |
| `refactor:` | Changed | `refactor: extract auth middleware` |
| `docs:` | Changed | `docs: update API reference` |
| `security:` or `vuln:` | Security | `security: patch XSS in renderer` |
| `deprecate:` | Deprecated | `deprecate: mark legacyAuth for removal` |
| `remove:` or `BREAKING CHANGE` | Breaking Changes ⚠️ | `remove: drop v1 API support` |
| `chore:`, `ci:`, `test:`, `build:` | *(omit from changelog)* | Internal changes |

Non-conventional commits: include under "Changed" if meaningful, skip if trivial.

### Step 4: Enrich

For each commit: Extract PR number `(#123)`, issue references `fixes #456`, author for attribution.

### Step 5: Generate

Output the formatted changelog section. Prepend to existing CHANGELOG.md if it exists.

## Version Bumping

Determine version bump from commit types:

```
BREAKING CHANGE or remove: → Major (1.0.0 → 2.0.0)
feat:                      → Minor (1.0.0 → 1.1.0)
fix:, perf:, security:     → Patch (1.0.0 → 1.0.1)
```

If multiple types exist, use the highest bump level.

```bash
# Check for breaking changes
if git log $RANGE --oneline | grep -qiE "BREAKING|remove:|^[a-f0-9]+ !"; then
  echo "MAJOR bump required"
elif git log $RANGE --oneline | grep -q "^[a-f0-9]* feat"; then
  echo "MINOR bump required"
else
  echo "PATCH bump required"
fi
```

## Integration

### With Release Workflow

```bash
# 1. Generate changelog
# 2. Update version in package.json
npm version minor --no-git-tag-version

# 3. Prepend changelog entry to CHANGELOG.md
# 4. Commit
git add CHANGELOG.md package.json
git commit -m "chore: release v1.2.0"
git tag v1.2.0

# 5. Push (with confirmation)
git push && git push --tags
```

### With GitHub Releases

```bash
# Create release with changelog as body
gh release create v1.2.0 --title "v1.2.0" --notes "$(cat /tmp/changelog-entry.md)"
```

## Verification

- [ ] All `feat:` commits → "Added"
- [ ] All `fix:` commits → "Fixed"
- [ ] Breaking changes marked with ⚠️
- [ ] PR/issue numbers linked
- [ ] Version bump matches commit types
- [ ] No internal commits (`chore:`, `ci:`, `test:`) leaked through
