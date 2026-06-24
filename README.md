# octo-observability-agentic-sdlc

Agentic SDLC skills and workflows for the OCTO Observability team.

Skills are loaded by [Claude Code](https://claude.ai/code). Each skill is a directory under `skills/` containing a `SKILL.md` file.

## Setup

```bash
git clone https://github.com/co-cddo/octo-observability-agentic-sdlc.git
cd octo-observability-agentic-sdlc
chmod +x setup.sh && ./setup.sh
```

This symlinks each skill into `~/.claude/skills/`. Restart Claude Code to pick them up.

## Skills

| Skill | Description |
|---|---|
| `po-story` | Generate INVEST-compliant user story and create it in Jira |
| `dev-analysis` | Generate SPDD enriched context from a Jira story |
| `dev-implement` | Generate REASONS canvas from a Jira story + analysis doc, then TDD code generation and PR |
| `dev-review` | Review a PR from dev-implement: AI-scored findings, interactive testing, gated merge/reject flow |

## Contributing

Raise a PR. The `octo-observability` team are admins of this repo.
