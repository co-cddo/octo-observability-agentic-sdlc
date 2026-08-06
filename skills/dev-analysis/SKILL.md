---
name: dev-analysis
description: Generate SPDD enriched context from a Jira story, with review loop and git commit. For developers in a repository.
metadata:
  type: skill
---

Generate a strategic-level enriched context document (SPDD Phase 0) from a Jira user story. Fetches the story via Atlassian MCP, explores the codebase concept-by-concept, produces an analysis document, submits it for developer review with an iterative loop, and commits to git with a PR.

**Entry point:** Use when a developer has a Jira story key and needs to generate the enriched context analysis before building the REASONS canvas.

**Prerequisites:** Must be run from within a git repository with the project codebase present. Requires git credentials and GitHub/Atlassian MCP access.

---

## Workflow

### Step 1: Gather input and configuration

Ask for:
```
1. Jira issue key (e.g., OB-401)
```

If not provided, ask the user:
> "Which Jira issue key should I analyze? (e.g., OB-123)"

Verify the key format matches `^[A-Z]+-\d+$`.

Detect Jira cloud ID from session context (should be available from prior Jira MCP operations). If not in session, ask:
```
2. Jira cloud domain (e.g., gds-digital-transformation.atlassian.net)
```

**Success criterion:** Have a valid Jira key and cloud ID.

---

### Step 2: Gather context (parallel)

Run all three of the following in parallel:

**a. Fetch Jira story:**

Call `mcp__atlassian__getJiraIssue`:

```
cloudId: {detected or provided}
issueIdOrKey: {user-provided key}
fields: ["summary", "description", "issuetype", "created", "assignee", "components", "labels"]
```

Extract from the returned issue:
- **Issue key** (e.g., `OB-401`)
- **Summary** (e.g., "Implement Real-Time SBOM Submission Monitoring Dashboard")
- **Description** (full Jira description with all acceptance criteria)
- **Type** (e.g., Story, Task)
- **Created date**
- **Labels** (if any — may inform concept extraction)

**b. Read existing SPDD context:**

List and read existing files in the project to establish naming conventions and prevent duplication:

i. **If `spdd/analysis/` exists:**
   - List files in the directory
   - Read the 2–3 most recent analysis files (sorted by filename timestamp)
   - Extract: JIRA key pattern (e.g., all use `GGQPA-XXX` or use real keys like `OB-`), naming conventions, existing concept inventories
   - Note: what areas have been analyzed already? Are there concepts that should be reused?

ii. **If `spdd/prompt/` exists:**
   - List files in the directory
   - Read the 2–3 most recent REASONS Canvas files
   - Extract: what strategic approaches have been used before? Any patterns or conventions in entity modeling, safeguards?

**c. Project fingerprint:**

Bootstrap understanding of the project quickly (do NOT read exhaustively).

i. **Primary build/dependency file (ONE file only):**
   - Detect: `package.json`, `pom.xml`, `build.gradle`, `requirements.txt`, `go.mod`, `Cargo.toml` (whichever exists)
   - Read it completely to detect:
     - Tech stack (Node.js, Java, Python, Go, Rust, etc.)
     - Key framework/library names
     - Relevant dependencies for the feature area

ii. **Directory structure:**
   - List top-level directories (names only, no file contents)
   - Infer layering convention: `src/`, `lib/`, `app/`, `services/`, `controllers/`, etc.

iii. **Main configuration file (ONE file only):**
   - Detect: `application.yml`, `.env`, `.env.example`, `next.config.js`, `webpack.config.js`, etc.
   - Read to understand:
     - Database choice (PostgreSQL, MongoDB, etc.)
     - Caching strategy (Redis, in-memory, etc.)
     - Messaging (Kafka, RabbitMQ, etc.)
     - Any other infrastructure choices

**Success criterion:** Jira story content, SPDD naming conventions, and project tech stack all available.

---

### Step 3: Extract search concepts from the Jira story

Analyze the story (summary + description + acceptance criteria) without touching code yet:

a. **Domain nouns** — entity/concept names likely to map to code:
   - Look for capitalized words, plural forms, business terms
   - Examples: "dashboard", "submission", "volume", "error", "repository", "GitHub"

b. **Action verbs** — operations likely to map to endpoints or services:
   - Examples: "display", "monitor", "collect", "submit", "drill-down"

c. **API surfaces** — any explicitly mentioned paths or endpoints:
   - Examples: `POST /api/submissions`, `GET /dashboard`

d. **Technical hints** — mentioned technologies, patterns, domain terms:
   - Examples: "real-time", "WebSocket", "aggregation", "time-series"

e. **Data/System boundaries** — what systems integrate?
   - Examples: "GitHub API", "Prometheus metrics", "dashboard UI"

**Output:** A curated list of 5–10 search concepts that will guide codebase exploration.

---

### Step 4: Targeted codebase exploration (2 parallel subagents)

Dispatch two subagents in parallel. Each receives: the extracted search concepts (from Step 3), the project tech stack and directory layout (from Step 2c).

---

**Subagent 1 — Schema exploration**

Prompt:
```
You are exploring a codebase to find schema and entity definitions for specific domain concepts.

Tech stack: {tech stack from Step 2c}
Directory layout: {top-level directories from Step 2c}
Search concepts: {concept list from Step 3}

Your task:
1. Search for schema/entity definitions matching the concepts:
   - Look in: db/migrations/, schema/, models/, entities/, or equivalent directories for this tech stack
   - For each concept, search for matching table/entity names
   - Read ONLY matched migrations/schema files — do NOT read all migrations
   - Follow foreign keys ONE HOP outward (e.g., if "submissions" references "repositories", read "repositories" too)

2. If the project uses an ORM (TypeORM, Hibernate, SQLAlchemy, GORM, etc.):
   - Search for entity/model classes matching concept names
   - Read matched files to understand attributes, relationships, and existing validation

Output format:
ENTITIES FOUND
{entity_name} — {source_file} — key attributes: {list} — relationships: {list}

(repeat for each entity found)

FOREIGN KEY HOPS
{source_entity} → {target_entity} — {relationship_type} — {target_file}

(repeat for each hop followed)

If no database/schema layer found: output "NO SCHEMA LAYER DETECTED — project may use external data sources or in-memory state."
```

---

**Subagent 2 — Code exploration**

Prompt:
```
You are exploring a codebase to find implementations matching specific domain concepts.

Tech stack: {tech stack from Step 2c}
Directory layout: {top-level directories from Step 2c}
Search concepts: {concept list from Step 3}

Your task:
1. Search by file name:
   - For each concept, search for files named *{Concept}* (e.g., *Submission*, *Dashboard*, *Repository*)
   - Read matched files to understand existing business logic, validation, error handling

2. Search by directory/package structure:
   - Infer likely locations based on project layout (e.g., if src/services/ exists, look there)
   - Read a representative file or two to understand coding style and patterns (naming, annotations, error handling)

3. One-hop dependencies:
   - If you read a service that injects or imports another service/client, read that too
   - Do NOT chain further — stop at one hop

4. Note architecture conventions:
   - What pattern is used? (Service layer? Repository pattern? Dependency injection style?)
   - Exception handling: custom exceptions or standard HTTP errors?
   - Validation: where is it done? (Controller? Service? Entity?)

Output format:
IMPLEMENTATIONS FOUND
{concept} — {file_path} — pattern: {pattern_used} — one-hop deps: {dependency_list}

(repeat for each concept with code found)

ARCHITECTURE CONVENTIONS
- Layering: {description}
- Error handling: {description}
- Validation: {description}
- Naming: {description}

If a concept has no matching implementation: report "{concept} — NO EXISTING IMPLEMENTATION FOUND"
```

---

**Success criterion:** Schema entities and code implementations for the story's concepts are mapped. Architecture conventions documented.

---

### Step 5: Read relevant prior SPDD artefacts

If `spdd/analysis/` or `spdd/prompt/` exist:

- Scan the 2–3 most recent files
- Read any whose titles/descriptions suggest they're related to the current story's domain
- Note: strategic approaches used before, entity modeling conventions, risk patterns surfaced

**Output:** Prior architectural decisions and risk patterns relevant to this story.

---

### Step 6: Generate analysis sections (3 parallel subagents)

Dispatch three subagents in parallel. Each receives: the full exploration results (from Step 4), the Jira story content (from Step 2a), the project fingerprint (from Step 2c), and prior SPDD context (from Step 5).

---

**Subagent 1 — Domain Concept Identification**

Prompt:
```
You are generating the Domain Concept Identification section of a strategic analysis document.

Jira Story:
- Key: {issue key}
- Summary: {summary}
- Description: {full description with acceptance criteria}

Project Tech Stack: {tech stack from Step 2c}

Schema Exploration Results:
{full output from Subagent 1 in Step 4}

Code Exploration Results:
{full output from Subagent 2 in Step 4}

Prior SPDD Context:
{relevant patterns from Step 5, or "None available"}

Your task: Synthesize these findings into a conceptual model. Output the following markdown section:

### Domain Concept Identification

#### Existing Concepts (from codebase)
- [ConceptName]: [business purpose] — [current role in system]
  Attributes/methods: [key ones from code exploration]
  Relationships: [which other concepts it relates to]

[... repeat for each existing concept relevant to the story ...]

#### New Concepts Required
- [ConceptName]: [business purpose] — [how it relates to existing concepts]
  Why new: [rationale from story requirements]

[... repeat ...]

#### Key Business Rules
- [Rule]: [which concepts it governs]
  Existing implementation: [if found in codebase]
  Gaps: [if not yet implemented]

[... repeat ...]

Quality standards you MUST follow:
- Grounded in actual code explored; not assumed
- Clear relationships between concepts
- Explicit about existing vs. new
- Business-level, not implementation-level
- Reference actual table columns, class names, file paths found in the exploration results
```

---

**Subagent 2 — Strategic Approach**

Prompt:
```
You are generating the Strategic Approach section of a strategic analysis document.

Jira Story:
- Key: {issue key}
- Summary: {summary}
- Description: {full description with acceptance criteria}

Project Tech Stack: {tech stack from Step 2c}

Schema Exploration Results:
{full output from Subagent 1 in Step 4}

Code Exploration Results:
{full output from Subagent 2 in Step 4}

Prior SPDD Context:
{relevant strategic approaches from Step 5, or "None available"}

Your task: Determine the high-level solution direction for this story. Output the following markdown section:

### Strategic Approach

#### Solution Direction
[High-level description of how to solve this story, drawing on the architecture and patterns discovered]

#### Key Design Decisions
- [Decision]: [trade-offs] → [recommendation and rationale]

[... repeat for each major design decision ...]

#### Alternatives Considered
- [Alternative approach]: [why rejected]

[... repeat ...]

Quality standards you MUST follow:
- References existing patterns discovered in code exploration results
- Clear rationale for trade-off decisions
- Grounded in project architecture, not generic advice
- Feasible with the tech stack and team patterns
- Do NOT include implementation-level details (specific queries, JSON shapes, method signatures)
```

---

**Subagent 3 — Risk & Gap Analysis**

Prompt:
```
You are generating the Risk & Gap Analysis section of a strategic analysis document.

Jira Story:
- Key: {issue key}
- Summary: {summary}
- Description: {full description with acceptance criteria}

Project Tech Stack: {tech stack from Step 2c}

Schema Exploration Results:
{full output from Subagent 1 in Step 4}

Code Exploration Results:
{full output from Subagent 2 in Step 4}

Prior SPDD Context:
{relevant risk patterns from Step 5, or "None available"}

Your task: Surface everything that could cause problems. Output the following markdown section:

### Risk & Gap Analysis

#### Requirement Ambiguities
- [Ambiguity]: [what needs clarification]
  Impact: [why it matters]

[... repeat ...]

#### Edge Cases
- [Scenario]: [why it matters for implementation]

[... repeat ...]

#### Technical Risks
- [Risk]: [potential impact and mitigation direction]

[... repeat ...]

#### Acceptance Criteria Coverage
| AC# | Description | Addressable with proposed approach? | Gaps/Notes |
|-----|-------------|-------------------------------------|-----------|
| 1 | ... | ... | ... |

[... one row per AC ...]

Quality standards you MUST follow:
- Specific to this story and codebase, not generic
- Clear impact/mitigation for each risk
- All ACs assessed individually
- Reference actual code, patterns, and constraints found in exploration results
```

---

**Success criterion:** Three complete markdown sections returned. If any subagent returns empty or errors, note the gap and generate that section inline before proceeding to assembly.

---

### Step 7: Assemble, name, and write the enriched context document

Combine all analysis into a final document and immediately persist it to disk so it is not lost if the session is interrupted.

#### 7a: Derive output file name

```
{JIRA}-{TIMESTAMP}-[Analysis]-{description}.md
```

Where:
- **JIRA**: The issue key extracted from Jira (e.g., `OB-401`) or `GGQPA-XXX` if key not reliably extractable
- **TIMESTAMP**: Current time in `YYYYMMDDHHmm` format (e.g., `202606161430`)
- **description**: Derived from Jira summary in kebab-case, max 10 words (e.g., `real-time-sbom-submission-dashboard`)

Example: `OB-401-202606161430-[Analysis]-real-time-sbom-submission-dashboard.md`

#### 7b: Assemble the document

```markdown
# SPDD Analysis: [Derived Title from Jira Summary]

**Original Jira Issue:** [{KEY}](https://[cloudId]/browse/{KEY})

**Issue Summary:** [One-line from Jira summary]

**Issue Type:** Story / Task / Bug

**Created:** [date from Jira]

---

## Original Jira Story

[COMPLETE Jira description — unmodified verbatim, including all acceptance criteria]

---

## Domain Concept Identification

[Output from Step 6 — Subagent 1]

---

## Strategic Approach

[Output from Step 6 — Subagent 2]

---

## Risk & Gap Analysis

[Output from Step 6 — Subagent 3]
```

**IMPORTANT:**
- The original Jira story MUST be included verbatim — do NOT paraphrase
- Every section must contain concrete, specific content — no placeholders
- Stay conceptual/strategic — do NOT include implementation details (specific queries, JSON shapes, method signatures, annotations, component inventories, step-by-step logic)

#### 7c: Write to disk immediately

```bash
mkdir -p spdd/analysis
```

Write the complete enriched context document to `spdd/analysis/{filename}.md`.

**This ensures the analysis is never lost even if the session ends unexpectedly.**

---

### Step 8: Display to developer for review

Show the complete enriched context document to the developer:

```
✅ Analysis Generated

[Display full document in a code block or formatted text]

---

**Happy with this, or describe changes you'd like?**

Examples of feedback I can handle:
- "Make the risk section more specific about the high-volume scenario"
- "Drop the alternative about static site generation"
- "Add a note about caching strategy"
- "Clarify the relationship between concepts X and Y"
```

Wait for feedback.

---

### Step 9: Review loop

Accept natural language feedback and regenerate affected sections only:

a. **If developer provides feedback:**
   - Identify which section(s) need changes
   - Regenerate only that section (don't regenerate the whole document)
   - **Update the file on disk** (`spdd/analysis/{filename}.md`) with the revised content
   - Re-display the full document with the updated section highlighted or marked

b. **If developer confirms** (e.g., "LGTM", "looks good", "yes"):
   - Proceed to Step 10

c. **If developer asks for more changes:**
   - Repeat 9a

**Key:** Preserve the review loop until developer explicitly confirms. Accept multiple rounds of refinement. Every revision is saved to disk immediately.

---

### Step 10: Git workflow — branch, commit, push, PR

a. **Create and checkout branch:**
   ```bash
   git checkout -b spdd/{JIRA-KEY}-{slug}
   ```
   Where `{slug}` is a short kebab-case summary (3-5 words) derived from the Jira story summary.
   Example: `git checkout -b spdd/OB-401-add-login-endpoint`

b. **Stage the file:**
   ```bash
   git add spdd/analysis/{filename}.md
   ```

c. **Commit (conventional commit format, no Claude attribution):**
   ```bash
   git commit -m "docs(spdd): add analysis for {JIRA-KEY}"
   ```
   Example: `git commit -m "docs(spdd): add analysis for OB-401"`

d. **Push with upstream (leveraging user's `push.autosetupremote = true`):**
   ```bash
   git push
   ```

e. **Create Pull Request (as draft)** via `mcp__github__create_pull_request`:
   ```
   title: "[{JIRA-KEY}] SPDD analysis"
   head: "spdd/{JIRA-KEY}-{slug}"
   base: "main" (or infer from repo default)
   body: [see Step 11]
   draft: true
   ```

---

### Step 11: PR body

Construct the PR description:

```markdown
## SPDD Analysis: {Jira Summary}

**Jira Issue:** [{KEY}](https://[cloudId]/browse/{KEY})

**Story Type:** [Story / Task / Bug]

---

### Key Design Decisions

{Extract 3–5 most important decisions from the Strategic Approach section}

Example:
- Real-time updates via polling every 15–30s (not WebSocket) to keep implementation simple and align with existing patterns
- Drill-down reveals repo-level breakdown and error type breakdown in a modal dialog
- Error rate threshold highlighting (>5%) to draw attention to elevated error periods

---

### Primary Risks & Mitigations

{Extract 2–3 most critical risks from the Risk & Gap Analysis section}

Example:
- High-volume metrics could overwhelm the charting library → aggregate per-minute before frontend
- Metrics API availability — dashboard shows stale data on unavailability (needs UX clarification)

---

### Analysis File

[File name and path: `spdd/analysis/{filename}.md`]

---

Generated via dev-analysis skill.
```

---

### Step 12: Update Jira issue

a. **Fetch available transitions** for the issue via `mcp__atlassian__getTransitionsForJiraIssue`:
   ```
   cloudId: [from session]
   issueIdOrKey: {JIRA-KEY}
   ```
   Extract transition names and IDs (e.g., "To Do" → "In Progress", "Ready" → "In Review")

b. **Automatically transition to In Progress:**
   - From the fetched transitions, find one whose name matches "In Progress" (case-insensitive; also accept "Start", "Start Development", "Begin" if "In Progress" is absent)
   - If found: call `mcp__atlassian__transitionJiraIssue` with that transition ID — no prompt needed
   - If no matching transition found: skip silently; note in Step 14 summary that transition was skipped

c. **Add Jira comment** via `mcp__atlassian__addCommentToJiraIssue`:
   ```
   cloudId: [from session]
   issueIdOrKey: {JIRA-KEY}
   commentBody: [see Step 13]
   contentFormat: "markdown"
   ```

---

### Step 13: Jira comment body

Construct a brief summary comment:

```markdown
✅ **SPDD Analysis complete**

Analysis file: `spdd/analysis/{filename}.md`

Pull Request: [View PR on GitHub]({PR URL})

**Key Decisions:** [2–3 bullet points from Strategic Approach]

**Next Step:** Review the PR, merge when ready. Then run the SPDD canvas generation.
```

---

### Step 14: Report success

Return to developer:

```
✅ Analysis and PR created successfully!

📋 Summary:
- Jira Issue: {KEY} - {Summary}
  → {Jira URL}
- Analysis File: spdd/analysis/{filename}.md
- Pull Request: {PR URL}
- Status Transitioned: In Progress ✅ (or "No matching transition found — skipped" if none available)

🔗 Next Steps:
- Review the PR and merge when ready
- Run the dev-implement skill to generate the REASONS Canvas
- Then /spdd-generate to write the implementation

💬 Feedback on the analysis? Ask for revisions anytime.
```

---

## Guardrails

- **Do NOT proceed without Jira key** — ask if not provided
- **Do NOT assume codebase structure** — read actual files to detect tech stack and layout
- **Do NOT exhaustively read codebase** — use concept-driven scoping from the story to target only relevant areas
- **Do NOT paraphrase the original Jira story** — preserve verbatim in output
- **Do NOT make assumptions** — read actual code; if something is unclear, surface it as an ambiguity or risk
- **Do NOT include implementation-level details** (specific queries, JSON shapes, method signatures, annotations) — those belong in REASONS Canvas
- **Do NOT commit or push without explicit user confirmation at review gate** — wait for developer to approve the analysis
- **Preserve review loop discipline** — regenerate only affected sections; do NOT force a new full-doc generation on every feedback
- **Analysis MUST be grounded in codebase exploration** — not generic advice
- **Domain concepts MUST reference actual code** (table names, class names, patterns found)
- **Strategic decisions MUST trade off** — show what was considered and why one was chosen
- **Risks MUST be specific** — not vague warnings; concrete scenarios

---

## Integration with SPDD Workflow

This skill is the **dev-side Phase 0** — bridges Jira (product source of truth) to git (technical source of truth):

```
Jira Story (created by po-story)
          ↓
  dev-analysis skill (you are here)
          ↓
  spdd/analysis/{KEY}-*.md (enriched context)
          ↓
  [Merge PR]
          ↓
  dev-implement skill (future)
          ↓
  spdd/prompt/{KEY}-*.md (REASONS Canvas)
          ↓
  /spdd-generate (Phase 2 command)
          ↓
  Implementation code
```

