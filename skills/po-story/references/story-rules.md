# Story rules

Rules for turning a natural-language requirement into a business-focused, INVEST-compliant user story. The interactive po-story skill ([../SKILL.md](../SKILL.md)) follows these rules, and so will the unattended runner, so keep workflow steps (Jira lookups, confirmations) out of this file.

The section headings in Part 2 are read by name by the dev-analysis and dev-implement skills, and the OB-1104 story template in Jira mirrors them. Change all three together.

**Inputs:**
- **Requirement** — the requester's own words, taken as given. Do not ask clarifying questions; record ambiguities in Open Questions (2h).
- **Request details** (if provided) — who asked, where the request came from, and the date.
- **Recent stories** (if provided) — titles, labels and AC format of recent stories in the project, for matching style and spotting duplicates.

---

## Part 1: INVEST analysis

### 1a: Abstract task identification

Analyze the requirement at a conceptual level:

```
### Abstract Task: "[Feature Name]"

**Analysis Dimensions**:
- **Core Responsibility**: [Primary purpose of this feature]
- **Primary Operations**: [Main operations: create, query, update, delete, list, search]
- **Key Constraints**: [Data uniqueness, permissions, associations, business rules]
- **Technical Complexity**: [Low/Medium/High]
- **Business Complexity**: [Low/Medium/High]
```

### 1b: INVEST compliance check

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

---

## Part 2: Write the story (or stories if split)

For each story (if 1 story, do this once; if 3 stories, repeat 3 times):

### 2a: Story title and number

Use the next available story number from Step 2. Format:

```
## [STORY-{NEXT-NUM}] {Operation Description} API Development
```

Example: `## [STORY-003] Create audit logging submission capability`

### 2b: Background section

```markdown
### Background
[Business motivation, role, use cases — 2–3 sentences]

Key points:
- **Business value and user needs:** [what the user needs and why it matters to them]
- **Relationship with other features:** [related stories, epic link, OKR / objective link]
- **Why this is needed now:** [impact if this is not done]
- **Requested by / source / date:** [who asked; where it came from, e.g. email, Slack thread, meeting, user research, support ticket; date requested]
- **Relevant context / links:** [documents, decisions or links mentioned in the requirement]
```

Take the request details from the inputs or the requirement. Where something isn't stated, write "Not stated" rather than guessing.

### 2c: Business Value section

```markdown
### Business Value
- Provide {specific capability} for {role}
- Support {specific need} in {business scenario}
- Enable {key function} of {system goal}
```

### 2d: Dependencies and Assumptions

```markdown
### Dependencies and Assumptions
- **Prerequisites**: [Features/stories that must be completed first, if any]
- **Data assumptions**: [What data/entities expected to exist]
- **Integration points**: [External systems, APIs, services]
- **Business constraints**: [Regulatory, contractual, organizational constraints]
```

### 2e: Scope In / Scope Out

```markdown
### Scope In
- [Feature included in this story — bullets]

### Scope Out
- [Feature NOT included — bullets]
```

### 2f: Acceptance Criteria

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

### 2g: Estimated effort

```markdown
### Estimated effort
[1–5 days, based on story size and functional points]
```

If the estimate is more than 5 days, go back to the Split Strategy in 1b.

### 2h: Open Questions

Write the best story the requirement supports, then list here anything it leaves ambiguous and any assumption the story relies on that the requirement doesn't state, so the team can settle them in refinement.

```markdown
### Open Questions
- [Specific question, naming the section or AC it affects, e.g. "AC2 assumes logs are kept for 30 days. Is that the right retention period?"]
```

If there are none, write `- None`.

### 2i: Quality check

Verify each generated story against:

**Structure**:
 - [ ] All required sections present (Background, Business Value, Dependencies/Assumptions, Scope In/Out, ACs, Estimated effort, Open Questions)
 - [ ] Each AC uses Given-When-Then with concrete values
 - [ ] ACs written in business language
 - [ ] ACs cover happy path, validation/rules, error conditions

**Business clarity**:
 - [ ] Business value clear for specific audience/role
 - [ ] Scope In/Out clearly delineate boundaries
 - [ ] No duplication with existing Jira stories
 - [ ] QA engineer could write test cases from ACs alone
 - [ ] Requester, source and date recorded (or marked "Not stated")
 - [ ] Every assumption the ACs rely on that the requirement doesn't state is listed in Open Questions

**Sizing**:
 - [ ] Max 2–3 functional points
 - [ ] Independently deliverable
 - [ ] 1–5 day workload estimate

---

## Content rules

- **Do NOT ask clarifying questions** — record ambiguities in Open Questions instead
- **Do NOT summarize the requester's words** — preserve full information when referencing
- **Do NOT leave placeholders** — generate complete, specific content
- **ACs MUST be in business language** — no technical implementation details
- **Each story MUST have concrete examples** — no vague acceptance criteria
- **Do NOT prescribe HOW** — only WHAT the expected behavior is
- **Do NOT specify error JSON formats or P99 metrics** — those belong in `/spdd-reasons-canvas` Safeguards, not ACs
