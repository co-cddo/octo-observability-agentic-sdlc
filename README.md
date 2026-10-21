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

## Story format

The rules po-story uses to write a story (INVEST analysis, story sections, acceptance criteria rules) live in [`skills/po-story/references/story-rules.md`](skills/po-story/references/story-rules.md), separate from the interactive steps in `SKILL.md`. They are kept free of workflow steps so a planned unattended runner can reuse them to draft stories for team members who don't have AI tools. [`docs/story-runner.md`](docs/story-runner.md) is the contract that runner implements.

If you change the story sections, also update:

- the OB-1104 story template in Jira, which mirrors them
- `dev-analysis` and `dev-implement`, which read the Business Value and Scope In/Out sections by name
- the runner's heading check in `docs/story-runner.md`

## Contributing

Raise a PR. The `octo-observability` team are admins of this repo.
