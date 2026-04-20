# Security Policy

## Reporting a Vulnerability

If you believe you've found a security issue in this kit — for example, a hook that can be bypassed, a script that enables injection, or a skill that leaks data — please **do not open a public issue**.

Instead, open a [private security advisory](https://github.com/Xza85hrf/claude-code-agent-kit/security/advisories/new) on GitHub. You'll get a response within a reasonable timeframe (typically a few days).

Please include:

- A description of the issue
- Steps to reproduce, ideally with a minimal example
- The kit commit SHA you tested against
- Your suggested fix, if any

## Scope

In scope:

- Hooks or scripts that allow execution of arbitrary commands
- Hooks that can be bypassed to allow forbidden operations (secrets writes, dangerous `rm`, etc.)
- Skills or agents that exfiltrate data, credentials, or environment variables
- MCP configuration templates that expose credentials
- Installation script vulnerabilities (TOCTOU, path traversal, insecure defaults)

Out of scope:

- Vulnerabilities in [Claude Code itself](https://docs.anthropic.com/en/docs/claude-code) — report to Anthropic
- Vulnerabilities in worker model providers (Ollama, OpenAI, etc.) — report to them
- Any issue that requires the user to first install malicious dependencies

## Responsible Disclosure

- We'll acknowledge your report
- We'll confirm the issue and scope the fix
- We'll patch, test, and release
- We'll credit you in the release notes (unless you prefer anonymity)

## Security Model Summary

This kit configures Claude Code for autonomous operation. Its safety posture rests on:

- **Path protection** — `damage-control.sh` blocks `rm -rf /`, `.env` access, and similar
- **Secrets scanning** — `check-secrets.sh` blocks API-key-shaped strings from being written
- **Git guards** — `block-dangerous-git.sh` prevents force-push and `reset --hard` without explicit bypass
- **Permission system** — Claude Code's `permissions.deny` is the authoritative block; hooks add advisory layers
- **Short-lived bypass tokens** — when a block must be overridden, tokens are filesystem-scoped and time-boxed (5 minutes)

If an attack surface isn't covered by one of those, treat it as a potential vulnerability and report it.
