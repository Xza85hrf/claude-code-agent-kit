# CI Workflow Safety Rules

## When Writing GitHub Actions Workflows

### File Handling
- **NEVER write intermediate files to the repo working directory** — actions like `peter-evans/create-pull-request` perform `git checkout` internally, deleting untracked files
- Use `${{ runner.temp }}/subdir/` for all intermediate files (reports, JSON, logs)
- Always `mkdir -p` the temp directory before writing

### JSON Output from CLI Tools
- **NEVER use `2>&1` when capturing JSON output** — stderr warnings corrupt the JSON
- Use `2>/dev/null` to discard stderr, or redirect to a separate file
- Always validate JSON before parsing: `jq empty file.json 2>/dev/null`
- Guard jq with fallback: `$(jq -r '.key // 0' file.json 2>/dev/null || echo "0")`

### bash -e (set -e) Awareness
- GitHub Actions uses `bash -e` by default — ANY non-zero exit kills the step
- Commands in `if` conditions are exempt, but subshells and command substitutions are NOT
- `jq` returns non-zero on parse errors — always guard or validate first
- Use `|| true` for commands where failure is acceptable

### npm-Specific
- `--production` is deprecated in npm 10+ — use `--omit=dev`
- `npm audit` exit codes: 0 = no vulns, non-zero = vulns found OR error
- `npm audit fix --force` can make breaking changes — always use `--package-lock-only` in CI

### Security (GitHub Actions Injection Prevention)
- **NEVER use `${{ }}` expressions directly in `run:` blocks** — command injection risk
- Move to `env:` block and reference as shell variables:
  ```yaml
  env:
    TITLE: ${{ github.event.pull_request.title }}
  run: echo "$TITLE"
  ```
- Risky inputs: issue titles/bodies, PR titles/bodies, commit messages, branch names

### Permissions
- Workflows creating PRs need: `can_approve_pull_request_reviews: true` + `default_workflow_permissions: write`
- Set via: `gh api repos/OWNER/REPO/actions/permissions/workflow --method PUT --field can_approve_pull_request_reviews=true --field default_workflow_permissions=write`
- Also set `permissions:` block in workflow: `contents: write`, `pull-requests: write`
