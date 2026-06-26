---
name: dev-implement
description: Generate REASONS canvas from a Jira story + analysis doc, with review loop, then TDD code generation, lint, build, and PR update. For developers in a repository.
metadata:
  type: skill
---

Generate the REASONS Canvas (R/E/A/S/O/N/S) from an existing analysis artefact and Jira story, review with developer, then generate implementation code and tests (TDD), commit everything, and update the GitHub PR. Output: a PR containing analysis doc, canvas, implementation, and tests. Jira transitions to "In Review".

**Entry point:** Use after `dev-analysis` has run for this issue — requires an existing analysis doc and Jira comment with PR URL.

**Prerequisites:** Must be run from within the project git repository. Requires Atlassian MCP, GitHub access (`gh` CLI or MCP), and a working dev environment (pnpm/npm/etc.).

---

## Workflow

### Step 1: Gather input and configuration

Accept Jira issue key from arguments. If not provided, ask:
> "Which Jira issue key should I implement? (e.g., OB-123)"

Verify format matches `^[A-Z]+-\d+$`.

Detect Jira cloud ID from session context. If not available, ask for cloud domain.

Confirm current working directory is a git repository (`git rev-parse --git-dir`). If not: error — "Must be run from within the project repository."

**Success criterion:** Valid Jira key, cloud ID, inside a git repo.

---

### Step 2: Fetch Jira story and comments

Call `mcp__atlassian__getJiraIssue`:
```
cloudId: {detected or provided}
issueIdOrKey: {KEY}
fields: ["summary", "description", "issuetype", "created", "labels", "comment"]
```

Extract:
- Summary, full description, acceptance criteria, issue type
- All comments (look for the `dev-analysis` comment in the next step)

---

### Step 3: Locate analysis artefact and determine branch/PR strategy

**Find the analysis comment:** Scan comments for the most recent one containing "SPDD Analysis complete" (posted by `dev-analysis`). Extract:
- Analysis file path (e.g. `spdd/analysis/OB-401-*.md`)
- PR URL (e.g. `https://github.com/co-cddo/repo/pull/2`)

If no such comment found: error — "No dev-analysis comment found on {KEY}. Run dev-analysis first."

**Determine PR state:** From the PR URL, extract owner, repo, and PR number. Call `mcp__github__pull_request_read` (method: `get`) to check whether the PR is open or merged.

**Case A — PR still open:**
- Checkout the existing branch: `git fetch origin && git checkout {branch-name-from-PR}`
- Read analysis file from disk (it's on this branch)
- New commits will be added here; PR will be updated (not recreated)

**Case B — PR already merged:**
- Analysis file is in main: `git checkout main && git pull`
- Read analysis file from disk
- Create new branch: `git checkout -b spdd/{KEY}-implementation`
- A new PR will be created at Step 16

**Case C — PR URL missing or unresolvable:**
- Search `spdd/analysis/` on current branch or main for `{KEY}-*.md`
- Create new branch: `git checkout -b spdd/{KEY}-implementation`
- A new PR will be created at Step 16

Note the case — it drives Step 16.

---

### Step 4: Read analysis artefact

Read the full analysis file identified in Step 3. This is the primary input to canvas generation — it contains the domain concept identification, strategic approach, and risk/gap analysis from the prior `dev-analysis` run.

---

### Step 5: Read codebase context

Re-fingerprint the project quickly (same approach as `dev-analysis` Steps 4–7):

a. **Primary build/dependency file** (ONE): `package.json`, `pom.xml`, `go.mod`, etc. — detect tech stack, key dependencies, and available scripts (`test`, `build`, `dev`, `lint`).

b. **Directory structure** — list top-level dirs. Infer source layout.

c. **Source files relevant to the story** — search by the domain concepts from the analysis doc. Read the 3–5 most relevant source files (routes, services, DB queries, models/types).

d. **Test patterns** — find existing test files (`*.test.ts`, `*_test.go`, `*.spec.js`, etc.). Read one or two to understand: test framework, mocking approach, file colocation convention.

e. **Dev server start command** — detect from `package.json` scripts or README: `pnpm dev`, `npm start`, `docker-compose up`, etc. Note the default port.

This context is needed for precise canvas content: method signatures, import paths, existing interfaces, test setup patterns.

---

### Step 6: Generate REASONS canvas

Using analysis doc + Jira story + codebase context, generate all 7 REASONS sections. Content MUST be project-specific — derive every entity, method name, file path, and coding pattern from actual code found in Step 5. Do NOT use generic or Java/Spring examples.

#### R — Requirements

```markdown
## Requirements
[One or two verb phrases describing the core problem and value]

Boundary: [what is in scope / out of scope — draw from analysis Scope In/Out]

Business value: [from Jira Business Value section]
```

Quality check: core requirement expressible in one sentence; reflects business value not implementation detail.

---

#### E — Entities

```markdown
## Entities
```mermaid
classDiagram
direction TB

class [ExistingEntity] {
    +type attributeName
    +method()
}

class [NewConcept] {
    +type attributeName
}

[ExistingEntity] "1" -- "N" [NewConcept] : relationship
```

**Existing entities** — use actual table columns / TypeScript interfaces / Go structs found in codebase. Include only attributes relevant to this story.

**New entities / value types** — define attributes consistent with existing naming conventions (camelCase for TS, snake_case for DB columns, etc.).

**Conservative constraint:** If existing data structures can meet requirements without change, do NOT propose new entities. Only introduce new concepts when the story genuinely requires them.
```

---

#### A — Approach

```markdown
## Approach

1. Solution strategy:
   - [High-level approach matching the Strategic Approach from the analysis doc]
   - [Key architectural decision + rationale]

2. Data access:
   - [How the implementation will query/write data — specific to this project's DB/ORM pattern]

3. Error handling:
   - [How errors surface to the caller — HTTP status codes, response shapes, following existing project patterns]

4. Security:
   - [Any auth, CSP, input validation constraints relevant to this feature]
```

---

#### S — Structure

```markdown
## Structure

### Dependencies (file → file)
1. [src/path/new-file.ts] depends on [src/path/existing-file.ts]
2. [existing-file.ts] extended by [new-file.ts]
...

### Layered responsibilities
1. [Route layer — e.g. src/server/routes/]: [responsibility for this feature]
2. [Query layer — e.g. src/db/queries.ts]: [responsibility]
3. [View layer — e.g. src/server/views/]: [responsibility]
...

### New files
- [path]: [purpose]
...
```

Use actual file paths from this project, not package notation.

---

#### O — Operations

This is the most critical section. List every implementation task in dependency order.

**TDD rule — MANDATORY:** Every `[Impl]` task MUST be immediately preceded by its `[Test]` task. No implementation without a test.

```markdown
## Operations

### [Test] Write failing test for {first component}
- File: `src/path/component.test.ts` (or equivalent for this project's test colocation convention)
- Test framework: {jest/vitest/go test/etc. — from Step 5 detection}
- Setup: {how to create a test instance — mock pool? supertest app? etc.}
- Test cases:
  - {happy path}: given {input}, expect {output}
  - {error case}: given {bad input}, expect {error response}
  - {edge case}: given {edge condition}, expect {behaviour}
- These tests MUST fail before implementation exists

### [Impl] Create {first component}
- File: `src/path/component.ts`
- Purpose: {what it does}
- Signature: `functionName(param: Type, param2: Type): ReturnType`
- Logic:
  1. {step 1}
  2. {step 2}
  3. {error case handling}
- Apply Norms: {relevant norms from N section}
- Apply Safeguards: {relevant constraints from S section}

### [Test] Write failing test for {second component}
...

### [Impl] Create {second component}
...
```

Continue this pattern for every component. Order tasks so that dependencies come first — if task B uses a function from task A, task A's [Test]+[Impl] pair comes before task B's pair.

---

#### N — Norms

```markdown
## Norms
[Derived from actual codebase patterns found in Step 5 — not generic advice]

1. Function style: [e.g. "All DB query functions take `pool: Pool` as first arg; return typed results"]
2. Route handlers: [e.g. "async (req, res) with try/catch; no unhandled promise rejections"]
3. TypeScript: [e.g. "strict: true; explicit return types on all exported functions; no `as` assertions"]
4. Error responses: [e.g. "never expose stack traces; return { error: string } with appropriate HTTP status"]
5. Testing: [e.g. "collocated *.test.ts; jest mock pattern for pool.query; no real DB connections in unit tests"]
6. Imports: [e.g. "named imports only; no default exports except for Express routers"]
7. [Add further norms specific to this project]
```

---

#### S — Safeguards

```markdown
## Safeguards

### Acceptance Criteria coverage
| AC# | AC description (verbatim from Jira) | Operations task(s) that implement it |
|-----|-------------------------------------|---------------------------------------|
| 1   | [verbatim AC text]                  | [Impl task name]                      |
...

### Functional constraints
- [e.g. "Polling interval: exactly 30s — do not use a shorter interval"]
- [derived from Jira ACs and analysis risk section]

### Security constraints
- [e.g. "All <script> tags must carry nonce=\"{{ cspNonce }}\" — no inline scripts without nonce"]
- [e.g. "Parameterised queries only — no string interpolation in SQL"]

### Data constraints
- [e.g. "normalisation_status values: 'pending' | 'complete' | 'failed' only — no other strings"]

### Non-functional
- [e.g. "Page must load within 2s; polling must not add >50ms to backend response time"]
- [from Jira Non-Functional Expectations section]

### Error handling
- MUST NOT expose internal error messages or stack traces to HTTP responses
- [any other error handling constraints from the analysis risk section]
```

---

### Step 7: Display canvas for review

```
✅ REASONS Canvas Generated

[Full canvas content — all 7 sections]

---

Happy with this, or describe changes you'd like?

Examples:
- "The Entities diagram is missing the services join"
- "The Operations section needs a test for the error type classification"
- "Safeguards should mention the CSP nonce requirement"
- "Approach section doesn't mention the Chart.js CDN decision"
```

Wait for feedback.

---

### Step 8: Canvas review loop

a. **If developer provides feedback:**
   - Identify which section(s) need changes
   - Regenerate only that section; re-display full canvas with changed section marked

b. **If developer confirms** ("LGTM", "looks good", "yes"):
   - Proceed to Step 9

c. **If developer asks for more changes:**
   - Repeat 8a

**Key:** Do NOT generate any code until canvas is explicitly approved. Multiple rounds of refinement are expected and welcome.

---

### Step 9: Derive canvas file name

```
{KEY}-{TIMESTAMP}-[Canvas]-{description}.md
```

- TIMESTAMP: current time `YYYYMMDDHHmm`
- description: kebab-case from Jira summary, max 10 words

Example: `OB-401-202606161530-[Canvas]-real-time-sbom-submission-dashboard.md`

---

### Step 10: Write canvas file

```bash
mkdir -p spdd/prompt
```

Write approved canvas to `spdd/prompt/{filename}.md`.

---

### Step 11: Commit canvas

```bash
git add spdd/prompt/{filename}.md
git commit -m "docs(spdd): add canvas for {KEY}"
git push
```

This checkpoint ensures the canvas is committed before code generation begins. If code generation fails partway through, the canvas is already persisted in git.

---

### Step 12: Generate tests — TDD red phase

Process Operations tasks in order. For each `[Test]` task:

- Generate the test file at the specified path
- Use the project's test framework (detected in Step 5)
- Tests MUST fail at this point (no implementation exists yet)
- Do NOT generate implementation files yet

After all `[Test]` files are written, run the test suite:
```bash
pnpm test  # (or equivalent)
```

Confirm tests fail for the expected reason (module not found, function not defined, etc.). If a test fails with a syntax error or import error in the test file itself, fix the test file before proceeding.

---

### Step 13: Generate implementation — TDD green phase

For each `[Impl]` task (in Operations order):

a. Generate the implementation file at the specified path.

b. Apply Norms from the canvas — coding style, dependency injection, error handling, TypeScript constraints.

c. Enforce Safeguards — no unsafe SQL interpolation, no exposed stack traces, validate at boundaries.

d. Run the tests for this specific component:
```bash
pnpm test -- --testPathPattern={test file}  # (or equivalent)
```

e. If tests still fail: diagnose and fix.

**"Fix canvas first" principle:** If a test failure reveals the canvas is wrong (incorrect method signature, missing entity attribute, wrong import path), update the relevant canvas section in `spdd/prompt/{filename}.md` first, then fix the code. Never patch code to work around a canvas error. After a canvas change, re-display the affected section to the developer before continuing.

Repeat for each `[Impl]` task until all tests pass.

---

### Step 14: Lint, full test run, and offer manual verification

Run the full quality pipeline:
```bash
pnpm lint   # (or detected equivalent: npx eslint, golangci-lint, etc.)
pnpm test   # full suite
pnpm build  # (if applicable — TypeScript compile, etc.)
```

Fix any lint errors. If tests fail after lint fixes, iterate. Do NOT commit failing code.

**After a clean build, offer manual verification:**

Using the dev server start command detected in Step 5, and the new/changed routes or UI surfaces from the canvas Operations section, construct a specific walkthrough:

```
✅ Build and tests passing!

Want to manually verify the change? Here's how:

Start the server: {detected start command, e.g. pnpm dev / docker-compose up}

Once running:
1. Open {detected URL, e.g. http://localhost:3000}
2. {Auth step if needed, e.g. "Log in via SSO — use the mock OIDC at http://localhost:8090 if running locally"}
3. Navigate to {specific path this feature adds, e.g. /monitoring}
4. You should see: {specific UI element to look for, e.g. "a new 'Monitoring' link in the nav, two line charts, and a 24-hour time axis"}
5. To test the drill-down: {specific interaction, e.g. "click a data point on the volume chart — a detail panel should appear showing top services and error breakdown"}
6. {Any other golden-path interaction from the Jira ACs}

Would you like me to start the dev server now? (yes / no / skip)
```

**If developer says yes:** Start the server in the background, monitor output for the "listening on port" / "ready" log line, then confirm:
> "Server is running. Try the walkthrough above."

**If developer says no or skip:** Proceed to Step 15.

**If developer reports a problem:** Treat it as a canvas/implementation issue — trace to the relevant Operations task, fix canvas first, then fix code. Re-run lint+tests before Step 15.

---

### Step 15: Commit implementation

Stage all new and modified implementation + test files (excluding the canvas file, which was committed in Step 11):

```bash
git add {implementation and test files}
git commit -m "feat({scope}): implement {short description} ({KEY})"
git push
```

If the canvas was updated in Step 13 (due to "fix canvas first" corrections), commit the updated canvas too:
```bash
git add spdd/prompt/{filename}.md
git commit -m "docs(spdd): update canvas for {KEY} based on implementation feedback"
git push
```

---

### Step 16: Update or create PR

**Case A — branch had an open PR (from Step 3):**
- PR exists; update its description using `gh pr edit {number} --body "..."` or `mcp__github__update_pull_request`

**Case B or C — new branch:**
- Create PR: `gh pr create --title "[{KEY}] {Jira summary}" --base main --body "..."`

In both cases, set the PR description to the body from Step 17.

---

### Step 17: PR body

```markdown
## {Jira Summary}

**Jira Issue:** [{KEY}]({Jira issue URL})
**Story Type:** {Story / Task / Bug}

---

### SPDD Artefacts

- Analysis: `spdd/analysis/{analysis filename}`
- REASONS Canvas: `spdd/prompt/{canvas filename}`

---

### Implementation Summary

{3–5 bullet points from canvas Operations — what was built, at a high level}

### Test Coverage

{List of test files with a one-line description of what each covers}

---

### Key Design Decisions

{3–5 bullets from canvas Approach section}

### Acceptance Criteria Coverage

| AC# | Description | Implemented by |
|-----|-------------|----------------|
{One row per AC from the Jira story}

---

Generated via dev-implement skill.
```

---

### Step 18: Add Jira comment

`mcp__atlassian__addCommentToJiraIssue`:
```
cloudId: [from session]
issueIdOrKey: {KEY}
commentBody: [see below]
contentFormat: "markdown"
```

Comment body:
```markdown
✅ **Implementation PR ready for review**

Canvas: `spdd/prompt/{canvas filename}`

Pull Request: [View PR on GitHub]({PR URL})

**Implemented:**
{2–3 bullet points from canvas Operations summary}

**Test coverage:** {N} test files — {comma-separated list of areas covered}

**Next Step:** Review and merge the PR.
```

---

### Step 19: Transition Jira to "In Review"

`mcp__atlassian__getTransitionsForJiraIssue` — find transition whose name matches "In Review" (case-insensitive; also accept "Review", "Code Review", "Ready for Review").

If found: call `mcp__atlassian__transitionJiraIssue` with that transition ID — no prompt needed.

If no matching transition found: skip silently; note in Step 20 summary.

---

### Step 20: Report success

```
✅ Implementation complete and PR ready!

📋 Summary:
- Jira: {KEY} - {Summary}
  → {Jira URL}
- Canvas: spdd/prompt/{canvas filename}
- Pull Request: {PR URL}
- Jira status: In Review ✅ (or "No matching transition — skipped")

🧪 Tests: {N} test files, all passing
📦 Build: clean

🔗 Next Steps:
- Review the PR (canvas + implementation + tests in one diff)
- If changes are needed, re-run dev-implement — it will update the existing branch
- Merge when approved
```

---

### Step 21 (optional): Take and upload a screenshot to the PR

Ask:

> "Would you like me to take a screenshot of the feature and attach it to the PR?"

If yes:

1. **Derive the URL** from context already in scope:
   - Check canvas Operations for UI routes/pages introduced by this story
   - Check implementation files for route definitions or page components
   - Check dev server config (`package.json` scripts, `.env`, `vite.config`) for base URL and port
   - Construct the full URL to the feature under review
2. State: `"I'll screenshot {URL} — reply to use a different page."` then proceed without waiting
3. Start the dev server if not already running (use the project's standard dev command)
4. Navigate to the derived URL using the browser tool and take a screenshot
5. Post as a PR comment:
   ```
   gh pr comment {PR URL} --body "![Screenshot]({image})"
   ```
   If inline image rendering fails, upload via the assets API and reference the returned URL:
   ```
   gh api repos/{owner}/{repo}/issues/{number}/assets --input {screenshot file}
   ```
6. Confirm: `"Screenshot added to PR."`

If the feature has no navigable UI (pure API/backend story), skip this step silently.

---

## Guardrails

- **Do NOT generate code before canvas is explicitly approved** — the review loop is mandatory
- **Do NOT skip test generation** — every `[Impl]` task in Operations MUST have a preceding `[Test]` task
- **Do NOT commit failing tests** — all tests must pass before Step 15
- **Do NOT commit broken lint or build** — fix all issues before committing
- **"Fix canvas first"** — when implementation fails, trace the root cause to a canvas section and update the canvas before patching the code
- **Do NOT call `/spdd-reasons-canvas` or `/spdd-generate`** — these are project-local commands; logic is inlined in this skill
- **Entity models MUST reference actual code** — table column names, TypeScript interfaces, Go structs found in the codebase; no assumed or generic structures
- **Norms MUST be derived from actual codebase patterns** — read the code; do not use generic defaults
- **Acceptance criteria verbatim** — quote AC text from Jira exactly in the canvas Safeguards and PR table; do not paraphrase
- **If analysis file not found:** error immediately — do not attempt canvas generation without a grounded analysis

---

## Integration with SPDD Workflow

```
Jira Story (created by po-story)
          ↓
  dev-analysis skill
          ↓
  spdd/analysis/{KEY}-*.md  +  GitHub PR (analysis branch)
          ↓
  dev-implement skill (you are here)
          ↓
  spdd/prompt/{KEY}-*.md  +  implementation code + tests
          ↓
  GitHub PR updated (or new PR if analysis already merged)
          ↓
  Jira → "In Review"
          ↓
  Code review → merge
```
