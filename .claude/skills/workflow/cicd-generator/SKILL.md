---
name: cicd-generator
description: Generate CI/CD pipeline configurations for GitHub Actions, GitLab CI, and other platforms. Use when setting up automated testing, deployment pipelines, or DevOps workflows.
argument-hint: "Create a GitHub Actions workflow for Node.js with lint, test, build, and deploy stages"
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
model: inherit
department: workflow
references: []
thinking-level: medium
---

# CI/CD Generator

Generate production-ready pipeline configurations. Detect the stack, generate the config, done.

## Detection

Auto-detect project type:

| File | Stack | Runner |
|------|-------|--------|
| `package.json` | Node.js | `node`, `npm`/`pnpm`/`yarn` |
| `pyproject.toml` or `requirements.txt` | Python | `python`, `pip`/`uv` |
| `go.mod` | Go | `go` |
| `Cargo.toml` | Rust | `cargo` |
| `Dockerfile` | Docker | `docker` |
| `pom.xml` or `build.gradle` | Java/Kotlin | `mvn`/`gradle` |

Detect package manager: `pnpm-lock.yaml` → pnpm, `yarn.lock` → yarn, `bun.lockb` → bun, else npm.

## GitHub Actions (Primary)

### CI Workflow — Node.js

`.github/workflows/ci.yml`:

```yaml
name: CI

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true

jobs:
  ci:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        node-version: [20, 22]

    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: ${{ matrix.node-version }}

      - uses: pnpm/action-setup@v4
        with:
          version: 9

      - name: Cache dependencies
        uses: actions/cache@v4
        with:
          path: ~/.pnpm-store
          key: ${{ runner.os }}-pnpm-${{ hashFiles('pnpm-lock.yaml') }}
          restore-keys: ${{ runner.os }}-pnpm-

      - run: pnpm install --frozen-lockfile
      - run: pnpm lint
      - run: pnpm typecheck
      - run: pnpm test -- --coverage
      - run: pnpm build

      - name: Upload coverage
        if: matrix.node-version == 22
        uses: actions/upload-artifact@v4
        with:
          name: coverage
          path: coverage/
```

### CI Workflow — Python

```yaml
name: CI

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

jobs:
  ci:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        python-version: ["3.11", "3.12"]

    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-python@v5
        with:
          python-version: ${{ matrix.python-version }}

      - name: Cache pip
        uses: actions/cache@v4
        with:
          path: ~/.cache/pip
          key: ${{ runner.os }}-pip-${{ hashFiles('requirements*.txt') }}

      - run: pip install -r requirements.txt -r requirements-dev.txt
      - run: ruff check .
      - run: mypy .
      - run: pytest --cov=src --cov-report=xml
```

### CD Workflow — Deploy on Release

```yaml
name: Deploy

on:
  release:
    types: [published]

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: production

    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: 22

      - run: pnpm install --frozen-lockfile
      - run: pnpm build

      - name: Deploy to Vercel
        uses: amondnet/vercel-action@v25
        with:
          vercel-token: ${{ secrets.VERCEL_TOKEN }}
          vercel-org-id: ${{ secrets.VERCEL_ORG_ID }}
          vercel-project-id: ${{ secrets.VERCEL_PROJECT_ID }}
          vercel-args: --prod
```

### Docker Build + Push

```yaml
name: Docker

on:
  push:
    tags: ["v*"]

jobs:
  docker:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - uses: docker/build-push-action@v6
        with:
          push: true
          tags: ghcr.io/${{ github.repository }}:${{ github.ref_name }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
```

## Common Patterns

### Preview Deployments (on PR)

```yaml
- name: Deploy Preview
  if: github.event_name == 'pull_request'
  run: vercel --token=${{ secrets.VERCEL_TOKEN }}
```

### Scheduled Tests

```yaml
on:
  schedule:
    - cron: "0 6 * * 1"  # Every Monday at 6am UTC
```

### Branch Protection

After creating CI workflow, configure branch protection:

```bash
gh api repos/{owner}/{repo}/branches/main/protection \
  --method PUT \
  --field required_status_checks='{"strict":true,"contexts":["ci"]}' \
  --field enforce_admins=true
```

## Best Practices

| Practice | Why |
|----------|-----|
| Pin action versions with SHA | Prevents supply chain attacks |
| Use `--frozen-lockfile` | Reproducible builds |
| Cache dependencies | 2-5x faster builds |
| Matrix test on multiple versions | Catch compatibility issues |
| `concurrency` with cancel-in-progress | Don't waste runner minutes |
| Upload artifacts | Debug failed builds |
| Separate CI and CD | Different triggers, different permissions |
| Use `environment` for deploys | Requires approval, tracks history |

## Security

- Never hardcode secrets in workflow files
- Use `${{ secrets.NAME }}` for all sensitive values
- Use `permissions` to restrict token scope:
  ```yaml
  permissions:
    contents: read
    packages: write
  ```
- Pin third-party actions to commit SHA, not tag

## GitLab CI Equivalent

`.gitlab-ci.yml`:

```yaml
stages:
  - test
  - build
  - deploy

test:
  stage: test
  image: node:22
  cache:
    paths:
      - node_modules/
  script:
    - npm ci
    - npm run lint
    - npm test

build:
  stage: build
  script:
    - npm run build
  artifacts:
    paths:
      - dist/

deploy:
  stage: deploy
  only:
    - tags
  script:
    - npm run deploy
```
