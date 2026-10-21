---
name: po-story
description: Generate INVEST-compliant user story and create it directly in Jira. For product owners creating requirements without technical knowledge.
metadata:
  type: skill
---

Generate a business-focused, INVEST-compliant user story from a natural-language requirement and post it directly to Jira. This skill handles Jira config discovery, product history context, story generation with business-focused acceptance criteria, and automatic issue creation.

**Entry point:** Use when a product owner has a business requirement and wants it turned into a Jira story.

**Input:** PO's natural-language description of the feature or capability needed.

---

## Workflow

### Step 1: Gather Jira configuration

Check if Jira config (cloud ID, project key) is known from prior conversation context. If not, ask the user directly in plain text (do NOT use `AskUserQuestion` — it requires predefined options and these are free-text inputs):

> "I need a few details to create the Jira story:
> 1. **Jira cloud domain** (e.g., "mycompany.atlassian.net" or just "mycompany")
> 2. **Project key** (e.g., "OCTO", "PROJ")
> 3. **Epic link or default sprint** (optional — can be set later if unknown)"

**IMPORTANT:** Ask ONLY these Jira configuration questions. Do NOT ask clarifying questions about the requirement itself (e.g., "what type of system?", "who is the audience?", "can you elaborate?"). Take the PO's requirement as-is and work with whatever information they provided. If details are ambiguous, surface them as risks in the Risk & Gap Analysis (Step 11) rather than interrogating the PO upfront.

Wait for the user's reply before proceeding.

Store these in conversation context so subsequent invocations in the same session don't re-ask.

**Success criterion:** Have cloudId (resolved from domain), projectKey, and confirmation that Atlassian MCP is accessible.

---

### Step 2: Fetch product history for context

Query existing stories via `mcp__atlassian__searchJiraIssuesUsingJql`:

```
JQL: project = {projectKey} AND issuetype = Story ORDER BY created DESC
Limit: 20 most recent stories
Fields: summary, description, created, customfield_* (story points if available)
```

**Process the results:**
- Extract story titles and numbering patterns (e.g., STORY-001, STORY-002)
- Note any recurring theme labels or epic associations
- Scan AC patterns (if description contains "Given-When-Then", note the format)
- Identify the next available story number

**Output for context injection:** Summary of last 5-10 story titles + naming/numbering pattern + observed AC format.

---

### Step 3: INVEST Analysis and story generation

Read [references/story-rules.md](references/story-rules.md) before continuing. It holds the story rules, shared with the unattended runner, that Steps 3 and 4 follow.

#### Step 3a–3b: Analyse the requirement

Produce the Abstract Task, the INVEST Evaluation and, if splitting is needed, the Split Strategy, as described in **Part 1** of the story rules.

#### Step 3c: Display INVEST analysis to PO

Show the Abstract Task and INVEST Evaluation to the PO before generating the story:

> "**Abstract Task Analysis:**\n\n{abstract-task-output}\n\n**INVEST Evaluation:**\n{invest-eval-output}\n\nContinuing story generation based on this analysis..."

If splitting is recommended, also show the split rationale.

---

### Step 4: Generate the story (or stories if split)

Write each story as described in **Part 2** of the story rules, including its quality check. Use the product history from Step 2 for the story number and to avoid duplicating existing stories.

---

### Step 5: Confirm with PO

Display the generated story summary to the PO:

```
**Generated Story:**

[STORY-003] Create audit logging submission capability

**Background:** [1–2 line summary]

**Scope In:**
- [bullet 1]
- [bullet 2]

**Scope Out:**
- [bullet 1]

**Estimated Effort:** 3–4 days
**Acceptance Criteria:** {AC count} scenarios

---

**Ready to post to Jira?** (Yes / No / Revise)
```

**Gate:** Do not proceed to Jira creation until PO explicitly confirms.

---

### Step 6: Create Jira issue

Call `mcp__atlassian__createJiraIssue` with mapped fields:

```
cloudId: {from Step 1}
projectKey: {from Step 1}
issueTypeName: "Story"
summary: {story title, e.g., "[STORY-003] Create audit logging submission capability"}
description: {full story body — all sections formatted as markdown}
additional_fields: {
  "labels": [{inferred-labels-from-requirement}, "generated-story"],
  [optional] "epic": {epic-id if provided in Step 1}
}
```

**Handle errors gracefully:**
- If Jira creation fails, report the error and offer to retry or debug
- Do not silently fail

---

### Step 7: Report and next steps

Return to PO:

```
✅ Story created successfully!

**Issue:** {JIRA-KEY} — {story-title}
**URL:** https://{cloudId}/browse/{JIRA-KEY}
**Acceptance Criteria:** {AC count} scenarios
**Estimated Effort:** {days} days

---

**Next steps:**
- If dev team needs detailed context: Run `/spdd-analysis @{JIRA-KEY}` (requires project checkout)
- If more stories needed: Describe the next requirement
- If revisions needed: Reply with feedback, I can regenerate
```

---

## Guardrails

- **Do NOT proceed without Jira config** — ask, don't assume
- **Do NOT create issue without PO confirmation** — explicit gate required
- **Do NOT assume existing story numbers** — always fetch from Jira to determine next available
- **Follow the content rules** in [references/story-rules.md](references/story-rules.md) — they apply to every story this skill writes

---

## Integration with downstream SPDD workflow

After the story is created in Jira, the dev team can run:

```
/spdd-analysis JIRA-KEY
  → Enriched context (domain concepts, strategy, risks)

/spdd-reasons-canvas
  → REASONS Canvas (technical approach, safeguards, implementation)

/spdd-generate
  → Implementation code
```

This skill generates the **"what"** and **"for whom"** layer. Dev team adds the **"why"** and **"how"** layers downstream.

---

## Troubleshooting

| Issue | Resolution |
|-------|-----------|
| "Atlassian MCP not accessible" | Verify Jira credentials. Check that `mcp__atlassian__` tools are available in this session. |
| "Project key not found" | Verify project key with user (case-sensitive). Check against `mcp__atlassian__getVisibleJiraProjects`. |
| "AC descriptions are too technical" | Rephrase using business language: "system rejects the request" instead of "return HTTP 400 with error code E_INVALID". |
| "Story is too large" | Split into 2–3 stories using the "By operation type" or "By complexity" dimension. Re-run analysis. |
| "Can't fetch product history" | Check JQL syntax. Verify issue type name is "Story" (case-sensitive in Jira). Retry with simpler JQL. |

