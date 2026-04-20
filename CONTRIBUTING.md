# Contributing to Claude Code Agent Kit

Thanks for your interest in contributing! This project provides configuration and tooling for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) (Anthropic's CLI). Contributions that improve the skills, hooks, documentation, or setup experience are welcome.

## Reporting Issues

Please open a [GitHub Issue](../../issues) with:

- **Description**: What's the problem or feature request?
- **Steps to Reproduce**: How to trigger the issue
- **Expected Behavior**: What should happen instead
- **Environment**: OS, Claude Code version, Ollama version (if relevant)

## Submitting Pull Requests

1. Fork the repository
2. Create a feature branch: `git checkout -b feat/my-improvement`
3. Make your changes
4. Test locally (see Development Setup below)
5. Commit using [conventional commits](https://www.conventionalcommits.org/): `feat:`, `fix:`, `docs:`, `chore:`
6. Open a Pull Request

## Development Setup

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/claude-code-agent-kit.git
cd claude-code-agent-kit

# Test the installer in a scratch project
mkdir /tmp/test-project
./install.sh /tmp/test-project --profile standard

# Sanity-check the install
cd /tmp/test-project
jq -r '.hooks | keys[]' .claude/settings.local.json   # event coverage
bash .claude/scripts/apply-profile.sh minimal         # switch profile
```

## Coding Standards

### Hooks (Shell Scripts)

- Read JSON from **stdin** using `jq` (not environment variables)
- Output JSON with `hookSpecificOutput` for PreToolUse hooks
- Use `$CLAUDE_PROJECT_DIR` for portable file paths
- Timeouts in **seconds** (not milliseconds)
- Always `exit 0` (non-zero exits cause errors in Claude Code)

```bash
# Example hook pattern
INPUT=$(cat)
TOOL_INPUT=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
# ... logic ...
jq -n '{ hookSpecificOutput: { permissionDecision: "allow" } }'
exit 0
```

### Skills

- One directory per skill: `skills/my-skill/SKILL.md`
- Structure: Overview, When to Use, The Process (phases/steps)
- Reference files go in `skills/my-skill/references/`
- Skills must work with explicit `Skill("name")` invocation

### Documentation

- Markdown with clear headers and tables for structured data
- Link to related docs using relative paths
- Keep files focused — one topic per document

## Adding a New Hook

1. Create `.claude/hooks/my-hook.sh`
2. Make it executable: `chmod +x .claude/hooks/my-hook.sh`
3. Register in `.claude/profiles/standard.json` (or `minimal.json`) under the appropriate event
4. Re-apply: `bash .claude/scripts/apply-profile.sh standard`
5. Test: `echo '{"tool_name":"Bash","tool_input":{"command":"echo test"}}' | ./.claude/hooks/my-hook.sh`

## Adding a New Skill

1. Create `.claude/skills/<category>/my-skill/SKILL.md` (category = architecture, engineering, quality, workflow, meta, integration, optimization)
2. Frontmatter must include `name` and `description`
3. Add to `.claude/skills/skill-table.md`

## Code of Conduct

Be respectful, constructive, and inclusive. We're all here to make AI-assisted development better.

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).
