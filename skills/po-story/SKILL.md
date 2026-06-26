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

#### Step 3a: Abstract task identification

Analyze the PO's requirement at a conceptual level:

```
### Abstract Task: "[Feature Name]"

**Analysis Dimensions**:
- **Core Responsibility**: [Primary purpose of this feature]
- **Primary Operations**: [Main operations: create, query, update, delete, list, search]
- **Key Constraints**: [Data uniqueness, permissions, associations, business rules]
- **Technical Complexity**: [Low/Medium/High]
- **Business Complexity**: [Low/Medium/High]
```

#### Step 3b: INVEST compliance check

Evaluate the requirement:

```
### INVEST Evaluation:
- ✅/❌ **Independent**: Can be developed, tested, deployed independently?
- ✅/❌ **Negotiable**: Can design details be discussed with the team?
- ✅/❌ **Valuable**: Does this provide clear business value?
- ✅/❌ **Estimable**: Can effort be estimated (1–5 days)?
- ✅/❌ **Small**: Can be completed within that timeframe?
- ✅/❌ **Testable**: Are there clear acceptance criteria?

**Conclusion**: [Needs splitting / Ready as-is]
```

If splitting is needed:

```
### Split Strategy
**Dimensions** (choose most appropriate):
 - By operation type: CREATE-READ / UPDATE-DELETE / LIST-SEARCH
 - By complexity: Basic / Advanced / Admin
 - By user role: Regular user / Admin
 - By technical dependency: Core / Extension

**Rules**:
 - Max 2–3 functional points per story
 - 1–5 day workload per story
 - Each story delivers independent business value
```

#### Step 3c: Display INVEST analysis to PO

Show the Abstract Task and INVEST Evaluation to the PO before generating the story:

> "**Abstract Task Analysis:**\n\n{abstract-task-output}\n\n**INVEST Evaluation:**\n{invest-eval-output}\n\nContinuing story generation based on this analysis..."

If splitting is recommended, also show the split rationale.

---

### Step 4: Generate the story (or stories if split)

For each story (if 1 story, do this once; if 3 stories, repeat 3 times):

#### 4a: Story title and number

Use the next available story number from Step 2. Format:

```
## [STORY-{NEXT-NUM}] {Operation Description} API Development
```

Example: `## [STORY-003] Create audit logging submission capability`

#### 4b: Background section

```markdown
### Background
[Business motivation, role, use cases — 2–3 sentences]

Key points:
- Business value and user needs
- Relationship with other features
- Why this capability is needed now
```

#### 4c: Business Value section

```markdown
### Business Value
- Provide {specific capability} for {role}
- Support {specific need} in {business scenario}
- Enable {key function} of {system goal}
```

#### 4d: Dependencies and Assumptions

```markdown
### Dependencies and Assumptions
- **Prerequisites**: [Features/stories that must be completed first, if any]
- **Data assumptions**: [What data/entities expected to exist]
- **Integration points**: [External systems, APIs, services]
- **Business constraints**: [Regulatory, contractual, organizational constraints]
```

#### 4e: Scope In / Scope Out

```markdown
### Scope In
- [Feature included in this story — bullets]

### Scope Out
- [Feature NOT included — bullets]
```

#### 4f: Acceptance Criteria

Generate business-focused ACs using Given-When-Then format. Cover:

**Happy path ACs** — core business scenarios with concrete examples:
```markdown
#### AC1: {Business Scenario Description}
**Given** {business precondition with concrete values/examples}
**When** {user action in business language}
**Then** {expected business outcome with specific numbers}
```

**Validation and business rule ACs**:
```markdown
#### AC{N}: {Validation Scenario}
**Given** {invalid or edge-case input condition}
**When** {user attempts the action}
**Then** {system rejects with clear user-facing message}
```

**Error condition ACs**:
```markdown
#### AC{N}: {Error Scenario}
**Given** {condition that causes failure}
**When** {user attempts the action}
**Then** {system responds with appropriate error and HTTP status}
```

**AC writing rules:**
- Use **business language**, not implementation details
- Include **concrete numbers and examples** (e.g., "100,000 monthly quota, 80,000 used" not "some quota")
- HTTP status codes ARE acceptable (part of API contract)
- Each AC independently testable by QA
- Do NOT prescribe HOW (no "use parameterized queries", "apply caching", etc.)
- Do NOT specify internal details (no JSON format, DB schema, error codes)

**Estimated effort:** Based on story size and functional points, estimate 1–5 days.

#### 4g: Quality check

Verify each generated story against:

**Structure**:
 - [ ] All required sections present (Background, Business Value, Dependencies/Assumptions, Scope In/Out, ACs)
 - [ ] Each AC uses Given-When-Then with concrete values
 - [ ] ACs written in business language
 - [ ] ACs cover happy path, validation/rules, error conditions

**Business clarity**:
 - [ ] Business value clear for specific audience/role
 - [ ] Scope In/Out clearly delineate boundaries
 - [ ] No duplication with existing Jira stories
 - [ ] QA engineer could write test cases from ACs alone

**Sizing**:
 - [ ] Max 2–3 functional points
 - [ ] Independently deliverable
 - [ ] 1–5 day workload estimate

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
- **Do NOT summarize the PO prompt** — preserve full information when referencing
- **Do NOT leave placeholders** — generate complete, specific content
- **ACs MUST be in business language** — no technical implementation details
- **Each story MUST have concrete examples** — no vague acceptance criteria
- **Do NOT prescribe HOW** — only WHAT the expected behavior is
- **Do NOT specify error JSON formats or P99 metrics** — those belong in `/spdd-reasons-canvas` Safeguards, not ACs

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

