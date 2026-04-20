#!/bin/bash
# detect-stack.sh — Analyze a project directory and output detected stack info
# Usage: bash detect-stack.sh [project-dir]
# Output: KEY=VALUE pairs (one per line, parseable)
set -euo pipefail

if ! command -v jq &> /dev/null; then
    echo "Error: jq is required but not installed" >&2
    exit 1
fi

PROJECT_DIR="${1:-.}"
if ! cd "$PROJECT_DIR" 2>/dev/null; then
    echo "Error: Cannot access directory '$PROJECT_DIR'" >&2
    exit 1
fi

PROJECT_NAME="" FRONTEND="" BACKEND="" DATABASE="" DEPLOY=""
LANGUAGES="" PACKAGE_MANAGER="" TEST_FRAMEWORK="" LINTER=""
COMMAND_INSTALL="" COMMAND_DEV="" COMMAND_BUILD="" COMMAND_TEST=""
COMMAND_TYPECHECK="" COMMAND_LINT="" AUTH="" PAYMENTS="" LAYOUT=""

has_file() { [[ -f "$1" ]]; }
has_dir() { [[ -d "$1" ]]; }

get_deps() {
    has_file "package.json" && jq -r '((.dependencies // {}) + (.devDependencies // {})) | keys[]' package.json 2>/dev/null || true
}

get_dep_version() {
    local ver
    ver=$(jq -r --arg dep "$1" '((.dependencies // {})[$dep] // (.devDependencies // {})[$dep] // "")' package.json 2>/dev/null)
    [[ "$ver" =~ [0-9]+ ]] && echo "${BASH_REMATCH[0]}"
}

has_dep() { get_deps | grep -qx "$1" 2>/dev/null; }
has_script() { has_file "package.json" && jq -r '.scripts // {} | keys[]' package.json 2>/dev/null | grep -qx "$1"; }
has_py_pkg() { grep -qiE "^${1}[>=<\[]" "${2:-requirements.txt}" 2>/dev/null || grep -qiE "^${1}$" "${2:-requirements.txt}" 2>/dev/null; }

# --- Project name ---
PROJECT_NAME=$(basename "$(pwd)")
if has_file "package.json"; then
    pkg_name=$(jq -r '.name // empty' package.json 2>/dev/null)
    [[ -n "$pkg_name" ]] && PROJECT_NAME="$pkg_name"
fi

# --- Package manager ---
if has_file "pnpm-lock.yaml"; then PACKAGE_MANAGER="pnpm"
elif has_file "yarn.lock"; then PACKAGE_MANAGER="yarn"
elif has_file "bun.lockb"; then PACKAGE_MANAGER="bun"
elif has_file "package-lock.json"; then PACKAGE_MANAGER="npm"
elif has_file "Pipfile"; then PACKAGE_MANAGER="pipenv"
elif has_file "pyproject.toml" && grep -q '\[tool.poetry\]' pyproject.toml 2>/dev/null; then PACKAGE_MANAGER="poetry"
elif has_file "requirements.txt"; then PACKAGE_MANAGER="pip"
fi

# --- Languages ---
if has_file "tsconfig.json"; then LANGUAGES="TypeScript"
elif has_file "package.json"; then LANGUAGES="JavaScript"
fi
(has_file "requirements.txt" || has_file "pyproject.toml" || has_file "setup.py" || has_file "backend/requirements.txt") && LANGUAGES="${LANGUAGES:+$LANGUAGES,}Python"
has_file "go.mod" && LANGUAGES="${LANGUAGES:+$LANGUAGES,}Go"
has_file "Cargo.toml" && LANGUAGES="${LANGUAGES:+$LANGUAGES,}Rust"
(has_file "pom.xml" || has_file "build.gradle") && LANGUAGES="${LANGUAGES:+$LANGUAGES,}Java"

# --- Frontend ---
if has_file "package.json"; then
    if has_dep "react"; then
        ver=$(get_dep_version "react")
        FRONTEND="React${ver:+ $ver}"
    elif has_dep "next"; then FRONTEND="Next.js"
    elif has_dep "vue"; then FRONTEND="Vue"
    elif has_dep "svelte"; then FRONTEND="Svelte"
    elif has_dep "@angular/core"; then FRONTEND="Angular"
    fi
    has_dep "vite" && FRONTEND="${FRONTEND:+$FRONTEND + }Vite"
    has_dep "tailwindcss" && FRONTEND="${FRONTEND:+$FRONTEND + }Tailwind"

    # Auth / Payments
    get_deps | grep -q "@clerk/" 2>/dev/null && AUTH="Clerk"
    has_dep "next-auth" && AUTH="${AUTH:+$AUTH + }NextAuth"
    has_dep "stripe" && PAYMENTS="Stripe"
fi

# --- Backend (check root and common subdirs) ---
PY_REQ=""
for candidate in requirements.txt backend/requirements.txt server/requirements.txt api/requirements.txt; do
    if has_file "$candidate"; then PY_REQ="$candidate"; break; fi
done
if [[ -n "$PY_REQ" ]]; then
    if has_py_pkg "fastapi" "$PY_REQ"; then BACKEND="FastAPI"
    elif has_py_pkg "flask" "$PY_REQ"; then BACKEND="Flask"
    elif has_py_pkg "django" "$PY_REQ"; then BACKEND="Django"
    fi
    has_py_pkg "sqlalchemy" "$PY_REQ" && BACKEND="${BACKEND:+$BACKEND + }SQLAlchemy"
    has_py_pkg "anthropic" "$PY_REQ" && BACKEND="${BACKEND:+$BACKEND + }Claude AI"
    has_py_pkg "ollama" "$PY_REQ" && BACKEND="${BACKEND:+$BACKEND + }Ollama"
    (has_py_pkg "asyncpg" "$PY_REQ" || has_py_pkg "psycopg2" "$PY_REQ" || has_py_pkg "psycopg2-binary" "$PY_REQ") && DATABASE="PostgreSQL"
    (has_py_pkg "pymongo" "$PY_REQ" || has_py_pkg "motor" "$PY_REQ") && DATABASE="${DATABASE:+$DATABASE + }MongoDB"
    has_py_pkg "redis" "$PY_REQ" && DATABASE="${DATABASE:+$DATABASE + }Redis"
    has_py_pkg "stripe" "$PY_REQ" && PAYMENTS="${PAYMENTS:-Stripe}"
fi
has_file "go.mod" && [[ -z "$BACKEND" ]] && BACKEND="Go"
has_file "Cargo.toml" && [[ -z "$BACKEND" ]] && BACKEND="Rust"
(has_file "pom.xml" || has_file "build.gradle") && [[ -z "$BACKEND" ]] && BACKEND="Java"

# --- Deploy (check root and common subdirs) ---
has_file "vercel.json" && DEPLOY="${DEPLOY:+$DEPLOY + }Vercel"
(has_file "railway.json" || has_file "Procfile" || has_file "backend/railway.json" || has_file "backend/Procfile") && DEPLOY="${DEPLOY:+$DEPLOY + }Railway"
has_file "fly.toml" && DEPLOY="${DEPLOY:+$DEPLOY + }Fly.io"
has_file "netlify.toml" && DEPLOY="${DEPLOY:+$DEPLOY + }Netlify"
has_file "docker-compose.yml" && DEPLOY="${DEPLOY:+$DEPLOY + }Docker Compose"
(has_file "Dockerfile" || has_file "backend/Dockerfile") && ! echo "$DEPLOY" | grep -q "Docker" && DEPLOY="${DEPLOY:+$DEPLOY + }Docker"
has_dir ".github/workflows" && DEPLOY="${DEPLOY:+$DEPLOY + }GitHub Actions"

# --- Test framework ---
if has_file "package.json"; then
    has_dep "vitest" && TEST_FRAMEWORK="vitest"
    [[ -z "$TEST_FRAMEWORK" ]] && has_dep "jest" && TEST_FRAMEWORK="jest"
    [[ -z "$TEST_FRAMEWORK" ]] && has_dep "mocha" && TEST_FRAMEWORK="mocha"
fi
for f in requirements-dev.txt requirements.txt pyproject.toml; do
    if has_file "$f" && grep -qi "pytest" "$f" 2>/dev/null; then
        TEST_FRAMEWORK="${TEST_FRAMEWORK:+$TEST_FRAMEWORK,}pytest"
        break
    fi
done

# --- Linter ---
if has_file "package.json"; then
    has_dep "eslint" && LINTER="eslint"
    has_dep "prettier" && LINTER="${LINTER:+$LINTER + }prettier"
fi
for f in requirements.txt requirements-dev.txt pyproject.toml; do
    if has_file "$f"; then
        grep -qi "ruff" "$f" 2>/dev/null && ! echo "$LINTER" | grep -q "ruff" && LINTER="${LINTER:+$LINTER,}ruff"
        grep -qi "black" "$f" 2>/dev/null && ! echo "$LINTER" | grep -q "black" && LINTER="${LINTER:+$LINTER,}black"
        grep -qi "flake8" "$f" 2>/dev/null && ! echo "$LINTER" | grep -q "flake8" && LINTER="${LINTER:+$LINTER,}flake8"
    fi
done

# --- Commands (from package.json scripts or Python conventions) ---
if has_file "package.json" && [[ -n "$PACKAGE_MANAGER" ]]; then
    COMMAND_INSTALL="$PACKAGE_MANAGER install"
    has_script "dev" && COMMAND_DEV="$PACKAGE_MANAGER dev"
    has_script "build" && COMMAND_BUILD="$PACKAGE_MANAGER build"
    if has_script "test:run"; then COMMAND_TEST="$PACKAGE_MANAGER test:run"
    elif has_script "test"; then COMMAND_TEST="$PACKAGE_MANAGER test"
    fi
    if has_script "typecheck"; then COMMAND_TYPECHECK="$PACKAGE_MANAGER typecheck"
    elif has_script "type-check"; then COMMAND_TYPECHECK="$PACKAGE_MANAGER type-check"
    fi
    has_script "lint" && COMMAND_LINT="$PACKAGE_MANAGER lint"
elif [[ -n "$PY_REQ" ]] || has_file "requirements.txt"; then
    req_file="${PY_REQ:-requirements.txt}"
    COMMAND_INSTALL="pip install -r $req_file"
    has_py_pkg "pytest" "$req_file" && COMMAND_TEST="pytest"
    has_file "pyproject.toml" && grep -q "pytest" pyproject.toml 2>/dev/null && COMMAND_TEST="pytest"
fi

# --- Layout ---
for dir in src app lib backend frontend pages components api server client docs; do
    has_dir "$dir" && LAYOUT="${LAYOUT:+$LAYOUT }$dir/"
done

# --- Output (only non-empty values) ---
[[ -n "$PROJECT_NAME" ]] && echo "PROJECT_NAME=$PROJECT_NAME"
[[ -n "$FRONTEND" ]] && echo "FRONTEND=$FRONTEND"
[[ -n "$BACKEND" ]] && echo "BACKEND=$BACKEND"
[[ -n "$DATABASE" ]] && echo "DATABASE=$DATABASE"
[[ -n "$DEPLOY" ]] && echo "DEPLOY=$DEPLOY"
[[ -n "$LANGUAGES" ]] && echo "LANGUAGES=$LANGUAGES"
[[ -n "$PACKAGE_MANAGER" ]] && echo "PACKAGE_MANAGER=$PACKAGE_MANAGER"
[[ -n "$TEST_FRAMEWORK" ]] && echo "TEST_FRAMEWORK=$TEST_FRAMEWORK"
[[ -n "$LINTER" ]] && echo "LINTER=$LINTER"
[[ -n "$COMMAND_INSTALL" ]] && echo "COMMAND_INSTALL=$COMMAND_INSTALL"
[[ -n "$COMMAND_DEV" ]] && echo "COMMAND_DEV=$COMMAND_DEV"
[[ -n "$COMMAND_BUILD" ]] && echo "COMMAND_BUILD=$COMMAND_BUILD"
[[ -n "$COMMAND_TEST" ]] && echo "COMMAND_TEST=$COMMAND_TEST"
[[ -n "$COMMAND_TYPECHECK" ]] && echo "COMMAND_TYPECHECK=$COMMAND_TYPECHECK"
[[ -n "$COMMAND_LINT" ]] && echo "COMMAND_LINT=$COMMAND_LINT"
[[ -n "$AUTH" ]] && echo "AUTH=$AUTH"
[[ -n "$PAYMENTS" ]] && echo "PAYMENTS=$PAYMENTS"
[[ -n "$LAYOUT" ]] && echo "LAYOUT=$LAYOUT"
