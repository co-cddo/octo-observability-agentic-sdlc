# Story runner contract

The story runner lets people without AI tools get a po-story story. They raise an OB ticket in their own words and add the `ai-draft` label. A scheduled job then rewrites the ticket's description as a story and posts its analysis as a comment. A person reviews the draft before refinement.

The runner lives in a separate private repo, because Action logs in this public repo would be public. It isn't built yet. This document is the contract it implements. Three files in this repo, read at a pinned commit, define what Claude is asked and must return:

| File | Role |
|---|---|
| [`skills/po-story/references/runner-prompt.md`](../skills/po-story/references/runner-prompt.md) | System instructions for unattended runs |
| [`skills/po-story/references/story-rules.md`](../skills/po-story/references/story-rules.md) | The story rules, shared with the interactive skill |
| [`skills/po-story/references/runner-output.schema.json`](../skills/po-story/references/runner-output.schema.json) | The structured-output schema for Claude's reply |

Changes to those files reach the runner only when its pinned commit is updated, in a reviewed PR.

## Labels

| Label | Added by | Meaning |
|---|---|---|
| `ai-draft` | A person | Draft (or redraft) this ticket |
| `generated-story` | The runner | Drafted successfully |
| `ai-failed` | The runner | Couldn't draft; the runner's comment says why |

## Each run

1. Search `project = OB AND labels = ai-draft ORDER BY updated ASC`, taking at most 5 tickets.
2. For each ticket, in turn: build the inputs, call Claude, check the reply, then write to Jira. A failure on one ticket doesn't stop the others.

Runs never overlap (a single GitHub Actions concurrency group), so a ticket is never processed twice at once.

## Building the inputs

Each input is sent as a tagged section of the user message, in the order listed in `runner-prompt.md`. Ticket content is converted from Jira's document format (ADF) to markdown; attachments and images are not sent. Before wrapping text in a tag, replace any occurrence of that tag's closing form in the text (for example `</request>`), so ticket text can't end its section early.

| Section | First draft | Redraft |
|---|---|---|
| `request` | The ticket's title and description | The ticket's title and the content of the Original request block. If someone deleted that block, use the whole description and say so in the comment. Never the AI's own draft. |
| `current_draft` | Not sent | The story part of the description, only if its hash differs from `draft_hash` (a person edited it) |
| `feedback` | All comments | Comments created after `drafted_at` |
| `request_details` | Reporter's display name; source "Jira ticket {KEY}"; the ticket's created date | Same |
| `recent_stories` | The same search as po-story Step 2: titles, labels, and whether each uses Given-When-Then | Same |
| `today` | Today's date | Same |
| `previous_attempt_problems` | Only on the retry described under Checks | Same |

Comments written by the runner's service account are never sent as feedback.

## The Claude call

- **System:** `runner-prompt.md` followed by `story-rules.md`, with a prompt-cache breakpoint after them, so tickets in the same run share the cached prompt.
- **User:** the tagged inputs.
- **Model:** Claude Opus 5.5 in an EU region. The model ID is configuration, for example `eu.anthropic.claude-opus-5-5`. Whether the runner reaches it through the organisation's AI gateway or Bedrock directly is still to be decided.
- **Settings:** `output_config: {effort: "high", format: {type: "json_schema", schema: <runner-output.schema.json>}}`, and `max_tokens` of 16000. Leave thinking at its default. No tools.
- **Stop reasons:** only `end_turn` is accepted. `refusal`, `max_tokens` or anything else is a failure.

## Checks before writing

The runner checks the reply before changing anything in Jira:

- `story_markdown` has these headings, once each and in this order: `### Background`, `### Business Value`, `### Dependencies and Assumptions`, `### Scope In`, `### Scope Out`, `### Acceptance Criteria`, `### Estimated effort`, `### Open Questions`. They are the Part 2 headings in `story-rules.md`; change both together.
- At least one AC has **Given**, **When** and **Then**.
- No heading mentions "Original request".
- Every `http` or `https` URL in the reply also appears in the inputs.
- `suggested_title` is one line of at most 255 characters.
- The finished description fits Jira's limit of 32,767 characters.
- If `status` is `not_drafted`, `reason` is not empty.

Labels are filtered rather than checked: keep at most three that appear on the recent stories, dropping `generated-story` and `template`.

If any check fails, call Claude once more with the failures listed in `previous_attempt_problems`. If the second reply also fails, treat it as a failure.

## What the runner writes

**Description**, built directly in ADF:

1. An info panel: "Drafted by AI on {date} from the original request at the bottom of this ticket. Check it before refinement. To change it, edit it or add a comment, then add the `ai-draft` label again."
2. The story (`story_markdown`, converted to ADF).
3. A divider.
4. An expand titled "Original request (kept by the AI runner)". On the first draft it holds the ticket's original description nodes, copied without conversion. On a redraft it is carried over unchanged. Any expand inside the original becomes a nested expand, as ADF requires.

**Title:** unchanged. The suggested title goes in the comment.

**Labels:** remove `ai-draft` and `ai-failed`; add `generated-story` and the filtered theme labels.

**Components:** add Build and keep any others.

**Comment:**

```
AI draft {n} of 5 for this ticket.

Suggested title: {suggested_title}

{analysis_markdown}

Could be split into further stories:        (only if any)
- {title}: {scope}

Notes for the reviewer:                      (only if any)
{notes_for_reviewer, then any runner notes}

Rules {short commit} · Model {model ID} · Run {link}
```

**Issue property** `po-story-runner`, which people can't see in Jira:

| Field | Value |
|---|---|
| `draft_hash` | SHA-256 of the story part's text, with whitespace collapsed, so formatting changes Jira makes on its own don't count as edits |
| `drafted_at` | When this draft was written |
| `draft_count` | Drafts so far, including this one |
| `rules_commit` | The pinned commit of this repo |
| `model` | The model ID used |
| `run_url` | Link to the Actions run |

## Failures and limits

Any failure, including `not_drafted`, a refusal or failed checks, gets the same treatment:
- remove `ai-draft` and add `ai-failed`;
- leave the description untouched;
- post a comment with the reason in plain words, what to do next and the run link.

A ticket can be drafted at most 5 times. After that, the runner adds `ai-failed` and comments asking a person to take it over.

## Security

- **Claude has no tools.** It only returns text for the one ticket being drafted.
- **Ticket text is treated as data.** It arrives in tagged sections, and `runner-prompt.md` tells Claude to treat it as data and to report any instructions it finds.
- **The runner only writes to the ticket it fetched.** The ticket key never comes from Claude's reply.
- **The reply is filtered.** Labels are limited to ones already in use, links to ones in the inputs, and the runner's own comments are never fed back in.
- **Logs stay private.** Logs and secrets live in the private repo; nothing in this repo is secret.

## Not covered yet

- An on-demand "Draft with AI" trigger from Jira, and running on AWS instead of GitHub Actions. Both have been considered and deferred.
- Choosing the route to Claude: the AI gateway or Bedrock directly.
- Reading attachments.
