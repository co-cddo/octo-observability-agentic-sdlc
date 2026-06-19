---
name: dev-review
description: Review a PR produced by dev-implement — AI-scored findings against REASONS canvas and Jira ACs, interactive manual testing, and gated merge/reject/request-changes flow. For tech leads reviewing a developer's implementation. Jira transitions to "Done" on merge.
metadata:
  type: skill
---

Review a PR produced by `dev-implement`: fetch the REASONS canvas, Jira story, and PR diff; dispatch three parallel AI review agents; score findings; surface a structured review package; offer interactive manual testing; then gate merge, request-changes, or reject — updating GitHub and Jira accordingly. Output: review artefact in `spdd/review/`, Jira transitioned, PR merged or annotated.

**Entry point:** Use after `dev-implement` has run for this issue — requires an open PR and a Jira comment from `dev-implement` containing `✅ **Implementation PR ready for review**`.

**Prerequisites:** Must be run from within the project git repository. Requires Atlassian MCP, GitHub access (`gh` CLI or `mcp__github__*`), and git credentials.

---

## Workflow

### Step 1: Gather input and validate state

Accept Jira issue key from arguments. If not provided, ask:
> "Which Jira issue key should I review? (e.g., OB-123)"

Verify format matches `^[A-Z]+-\d+$`.

Detect Jira cloud ID from session context. If not available, ask for cloud domain (e.g., `gds-digital-transformation.atlassian.net`).

**Fetch the Jira issue:**

Call `mcp__atlassian__getJiraIssue`:
```
cloudId: {detected or provided}
issueIdOrKey: {KEY}
fields: ["summary", "description", "issuetype", "status", "comment", "assignee"]
```

Extract:
- Summary, full description, all acceptance criteria (from description body), issue status name, all comments

**Status check:**

If issue status is NOT "In Review" (case-insensitive): display this warning and offer a choice:

```
⚠️  Issue {KEY} is currently in '{status}' — expected 'In Review'.
    This may mean dev-implement has not been run yet, or the PR was already merged/closed.

[1] Continue anyway
[2] Abort
```

Proceed only if reviewer chooses [1]. Abort cleanly if [2].

**Locate PR URL and canvas filename:**

Scan all Jira comments (most recent first) for one containing the exact text `✅ **Implementation PR ready for review**`. From that comment, extract:
- PR URL: from the line starting with `Pull Request:` (e.g. `Pull Request: [View PR on GitHub](https://github.com/co-cddo/repo/pull/42)`)
- Canvas filename: from the line starting with `Canvas:` (e.g. `Canvas: spdd/prompt/OB-401-202606161530-[Canvas]-real-time-sbom-submission-dashboard.md`)

If no such comment found: halt — "No dev-implement comment found on {KEY}. Run dev-implement first."

Extract PR number from the URL (the integer after `/pull/`). Extract owner and repo from the URL path (e.g. `co-cddo` / `octo-observability-sbom-service`).

**Success criterion:** Valid Jira key, cloud ID, PR number, canvas filename all resolved.

---

### Step 2: Fetch context (parallel)

Run all four of the following in parallel:

**a. Fetch PR details:**
```
gh pr view {PR_NUMBER} --repo {owner}/{repo} --json title,body,additions,deletions,changedFiles,statusCheckRollup,reviews,headRefName,baseRefName
```

**b. Fetch PR diff (full, for subagents):**
```
gh pr diff {PR_NUMBER} --repo {owner}/{repo}
```
Also fetch diff stats separately:
```
gh pr diff {PR_NUMBER} --repo {owner}/{repo} --stat
```

**c. Read REASONS canvas:**
Read the canvas file at path `{canvas-filename}` (extracted in Step 1). If the file does not exist at that path: warn — "Canvas file not found at {path} — canvas compliance check will be skipped." Continue without it; set `canvas_available = false`.

**d. Read analysis doc:**
Glob `spdd/analysis/{KEY}-*.md`. Read the most recently modified match. If none found: warn — "Analysis doc not found — skipping analysis reference." Continue.

**Success criterion:** PR JSON, full diff text, and (if available) canvas content all in memory. CI check results available from PR JSON `statusCheckRollup`.

---

### Step 3: Run AI review (3 parallel subagents)

Dispatch three subagents in parallel. Each receives: the full PR diff, the REASONS canvas (or a note that it is unavailable), the Jira acceptance criteria verbatim, and the CI check results.

---

**Subagent 1 — Canvas compliance** (skip if `canvas_available = false`)

Prompt:
```
You are reviewing a pull request against its REASONS canvas (a structured design document).

REASONS Canvas:
{canvas content}

PR Diff:
{full diff}

Jira Acceptance Criteria:
{AC text verbatim}

Your task:
1. For each `[Impl]` task listed in the canvas Operations section: does the diff contain a change to the file specified in that task? Report ✓ or ✗ for each, with evidence (file name found or "not in diff").
2. For each row in the AC coverage table in the canvas Safeguards section: does the diff include a change to the test file listed for that AC? Report ✓ or ✗.
3. List any files mentioned in the canvas Structure section (new files to create) that are absent from the diff.

Output format:
OPERATIONS COVERAGE
[Impl] {task name} — ✓ {file} | ✗ NOT IN DIFF

AC COVERAGE
AC{N}: {text} — ✓ {test file} | ✗ NO TEST FOUND

STRUCTURE GAPS
{file path} — not created
(or: none)
```

---

**Subagent 2 — Bug & quality**

Prompt:
```
You are reviewing a pull request for bugs, security issues, and code quality.

PR Diff:
{full diff}

Your task:
1. Identify bugs: logic errors, off-by-one errors, null/undefined dereferences, incorrect async handling.
2. Identify security issues (OWASP Top 10): SQL injection, XSS, insecure direct object reference, missing auth checks, hardcoded secrets, missing input validation at system boundaries.
3. Identify TypeScript strictness violations: implicit `any`, missing return types on exported functions, unsafe `as` casts.
4. Categorise each finding as Critical, Important, or Minor.

Output format (one finding per line):
[CRITICAL|IMPORTANT|MINOR] file/path.ts:{line} — {problem} — {suggested fix}

If no findings: output "NO FINDINGS".
```

---

**Subagent 3 — Test coverage**

If `canvas_available = false`: omit canvas-related tasks (1, 2, 4) from the prompt and note "Canvas unavailable" in the preamble. Task 3 (CI status) always runs.

Prompt:
```
You are reviewing the test coverage of a pull request against its REASONS canvas.

{if canvas_available: "REASONS Canvas (Operations section):\n{canvas Operations section only}" else: "REASONS Canvas: UNAVAILABLE — skip canvas-specific tasks below."}

PR Diff:
{full diff}

CI check results:
{statusCheckRollup JSON}

Your task:
{if canvas_available:
1. For each `[Test]` task in canvas Operations: is there a corresponding test file change in the diff? Report ✓ or ✗.
2. For each `[Impl]` task in canvas Operations: is there a preceding `[Test]` task? If an `[Impl]` has no `[Test]` entry at all in the canvas, flag it as a canvas design gap.
}
3. Report CI check status: passing / failing / pending for each check.
{if canvas_available:
4. List any test files changed in the diff that are NOT referenced in the canvas (bonus tests).
}

Output format:
TEST TASK COVERAGE
[Test] {task name} — ✓ {test file changed} | ✗ NOT IN DIFF

IMPL WITHOUT TEST
[Impl] {task name} — no preceding [Test] task in canvas

CI STATUS
{check name}: ✓ passing | ✗ failing | ⏳ pending

BONUS TESTS
{file} (not in canvas)
```

---

**Confidence score calculation:**

After all three subagents return, calculate:

```
score = 100
score -= 20 × (count of CRITICAL findings from Subagent 2)
score -= 10 × (count of IMPORTANT findings from Subagent 2)
score -= 2  × (count of MINOR findings from Subagent 2)
score -= 15 × (count of ✗ in OPERATIONS COVERAGE from Subagent 1)
score -= 10 × (count of ✗ in AC COVERAGE from Subagent 1)
score -= 10 × (count of entries in IMPL WITHOUT TEST from Subagent 3)
score = max(score, 0)
```

Score bands:
- ≥ 90 → GREEN
- 70–89 → AMBER
- < 70 → RED

---

### Step 4: Assemble and display Review Package

Using the PR JSON, subagent outputs, and calculated score, display the following block. Use exact ✓/✗/🔴/🟡/⚪ symbols. Replace all `{placeholders}` with actual values.

If score band is RED (<70): prepend the review package with:
```
🔴 WARNING: Score {score}/100 — significant issues found. Review all Critical findings before proceeding.
```

```
═══════════════════════════════════════════════════════
REVIEW: {KEY} · {Jira Summary}
Score: {score}/100 ({GREEN|AMBER|RED})   PR: #{PR_NUMBER} — +{additions}/-{deletions} lines, {changedFiles} files
Branch: {headRefName} → {baseRefName}
═══════════════════════════════════════════════════════

JIRA ACCEPTANCE CRITERIA
{for each AC row from Subagent 1 AC COVERAGE output:}
  ✓ AC{N} — {AC text} — covered by {test file}
  ✗ AC{N} — {AC text} — NO TEST FOUND
{if canvas_available = false: "(Canvas unavailable — AC coverage check skipped)"}

CANVAS COMPLIANCE ({count of ✓} / {total} Operations tasks reflected)
{for each row from Subagent 1 OPERATIONS COVERAGE output:}
  ✓ [Impl] {task name} — {file}
  ✗ [Impl] {task name} — NOT IN DIFF
{if canvas_available = false: "(Canvas unavailable — compliance check skipped)"}

FINDINGS ({total finding count} total)
{for each CRITICAL finding from Subagent 2:}
  🔴 CRITICAL: {file}:{line} — {problem}
{for each IMPORTANT finding:}
  🟡 IMPORTANT: {file}:{line} — {problem}
{for each MINOR finding:}
  ⚪ MINOR: {file}:{line} — {problem}
{if NO FINDINGS: "  ✓ No findings"}

CI: {count passing}/{total} checks passing   |   Reviews: {count approvals} approval(s)
```

---

### Step 5: Manual testing (agent-driven, interactive)

**5a — Offer testing (ask first, start nothing yet)**

Before starting any server or seeding, extract from the canvas Norms section:
- Dev server command (e.g. `pnpm dev`, `npm start`, `docker-compose up`)
- Default port (e.g. `3000`, `8080`)
- Seed command if present (e.g. `npm run seed`, `npm run db:migrate`)

From the PR diff, identify new or modified routes (look for additions to route handler files — lines beginning with `+` that contain `router.`, `app.get`, `app.post`, `fastify.route`, `@Get`, `@Post`, etc.).

Present to the reviewer:

```
Would you like to do manual testing?

[1] Browser — open the feature UI
    → I will start the server ({dev-server-command}), then open http://localhost:{PORT}/{primary-feature-route}
    → Walk-through: {2–3 steps derived from Jira ACs}

[2] API — run curl commands against the new endpoints
    → I will start the server and execute {count} curl command(s), showing each response

[3] Both — browser first, then API

[4] Skip manual testing
```

If reviewer picks [4]: proceed directly to Step 6. Do NOT start the server or run any commands.

---

**5b — Setup (only if [1], [2], or [3] chosen)**

Execute in sequence:

1. **Install dependencies** — check whether `node_modules` (or equivalent) is absent or older than the lockfile. If so, run the install command detected from the build file (e.g. `npm install`, `pnpm install`). Show output. If it fails, surface error verbatim and ask: "Installation failed — continue anyway? [y/n]"

2. **Resolve env vars** — check for `.env.example`. Copy it to `.env` if `.env` does not already exist: `cp .env.example .env`. Identify any vars that appear unset (empty value or placeholder like `CHANGE_ME`). List them to the reviewer. Proceed — do not block on unset vars unless the start command clearly requires them.

3. **Start dev server in background** — run the dev server command in the background, capturing output to a temp file:
   ```bash
   {dev-server-command} > /tmp/devserver-{KEY}.log 2>&1 &
   echo $! > /tmp/devserver-{KEY}.pid
   ```
   Wait up to 10 seconds for the port to become reachable: `curl -s --retry 5 --retry-delay 2 http://localhost:{PORT}/`. If still not reachable after 10s: show last 20 lines of `/tmp/devserver-{KEY}.log` and ask: "Server may not have started — continue anyway? [y/n]"

4. **Seed data** — if a seed command was found: ask "Run seed command (`{seed-command}`)? This may modify your local database. [y/n]". Only run if reviewer confirms. Show output.

---

**5c — Browser walkthrough (option [1] or [3])**

Open the browser:
```bash
open "http://localhost:{PORT}/{primary-feature-route}" 2>/dev/null || xdg-open "http://localhost:{PORT}/{primary-feature-route}"
```

Then display a step-by-step walkthrough, pausing for confirmation after each step:

```
Browser opened. Follow these steps:

Step 1: {Derived from first Jira AC — e.g. "Log in as a user with the '{role}' role"}
         → Confirm when done: [press Enter]

Step 2: {Derived from second Jira AC — e.g. "Navigate to {feature route} and verify {expected behaviour}"}
         → Confirm when done: [press Enter]

Step 3: {Derived from edge-case AC — e.g. "Trigger the error state by {action} — verify {expected error behaviour}"}
         → Confirm when done: [press Enter]
```

After all steps: "Browser walkthrough complete."

---

**5d — API curl commands (option [2] or [3])**

For each new or modified route identified from the PR diff, construct and execute one curl command. Use:
- Method from the route handler (GET, POST, PUT, DELETE, PATCH)
- Path from the route definition
- Example request body derived from the Jira AC scenario for that route (if an AC describes a specific payload shape, use those values; otherwise use minimal valid values)
- Auth header: `Authorization: Bearer $TOKEN` (note: reviewer must set `TOKEN` in their shell, or omit if the route is unauthenticated)

Execute each curl:
```bash
curl -s -w "\nHTTP %{http_code}" -X {METHOD} http://localhost:{PORT}{path} \
  {-H "Authorization: Bearer $TOKEN" if authenticated} \
  {-H "Content-Type: application/json" -d '{body}' if POST/PUT/PATCH}
```

After each response: display the response body and HTTP status. State whether the HTTP status matches the expected outcome from the AC (e.g. "Expected: 201 Created — Got: 201 ✓" or "Expected: 201 — Got: 500 ✗"). Ask: "Continue to next curl? [y/n]". If reviewer says n: skip remaining curls.

---

**5e — Teardown**

After testing is complete (or if reviewer skipped after [1]/[2]/[3]): ask:

```
Stop the dev server? [y/n]
```

If yes:
```bash
kill $(cat /tmp/devserver-{KEY}.pid) 2>/dev/null
rm -f /tmp/devserver-{KEY}.pid /tmp/devserver-{KEY}.log
```

If no: report "Server still running on port {PORT} (PID {PID}). Stop it manually with: `kill {PID}`"

---

### Step 6: Save review artefact

Before any merge or close action, write the review artefact. Determine the filename:
- Timestamp: current time as `YYYYMMDDHHmm` (e.g. `202606191045`)
- Description: kebab-case summary of the Jira story (e.g. `real-time-sbom-submission-dashboard`)
- Full path: `spdd/review/{KEY}-{timestamp}-[Review]-{description}.md`

Write the file with this structure:

```markdown
---
skill: dev-review
jira: {KEY}
pr: {PR_URL}
score: {score}
band: {GREEN|AMBER|RED}
reviewer: {output of: git config user.name}
reviewed_at: {ISO 8601 timestamp, e.g. 2026-06-19T10:45:00Z}
canvas: {canvas filename or "unavailable"}
analysis: {analysis filename or "unavailable"}
---

# Review: {KEY} — {Jira Summary}

## Score: {score}/100 ({band})

## AC Coverage
| AC# | Text | Status | Test file |
|-----|------|--------|-----------|
{one row per AC from Subagent 1 AC COVERAGE output}

## Canvas Compliance
| Task | Status | Evidence |
|------|--------|----------|
{one row per Operations task from Subagent 1 OPERATIONS COVERAGE output}

## Findings

### Critical
{list, or "None"}

### Important
{list, or "None"}

### Minor
{list, or "None"}

## CI Status
{statusCheckRollup results, one line per check}

## Decision
{Filled in after Step 7}
```

Create the `spdd/review/` directory if it does not exist: `mkdir -p spdd/review`.

Commit the artefact:
```bash
git add spdd/review/{filename}
git commit -m "chore({KEY}): add review artefact [Review]"
```

**Success criterion:** File written and committed before any merge/close action.

---

### Step 7: Decision gate

Display:

```
DECISION
────────
[1] Approve & Merge  (Score: {score}/100 · {band}{if AMBER or RED: " — review findings above"})
[2] Request Changes
[3] Reject / Close PR

Choice:
```

---

**Path [1] — Approve & Merge**

Ask:
```
Merge strategy? (default: squash)
[1] Squash merge (recommended — clean history)
[2] Merge commit
[3] Rebase and merge
```

Execute the chosen strategy:
```bash
# squash (default)
gh pr merge {PR_NUMBER} --repo {owner}/{repo} --squash --auto

# merge commit
gh pr merge {PR_NUMBER} --repo {owner}/{repo} --merge --auto

# rebase
gh pr merge {PR_NUMBER} --repo {owner}/{repo} --rebase --auto
```

If merge fails (e.g. conflicts, failed CI): surface the error output verbatim. Do NOT attempt to auto-resolve conflicts. Ask: "Merge failed — would you like to request changes or close the PR instead? [2/3]"

**Update artefact:** Append to the `## Decision` section of `spdd/review/{filename}`:
```
Approved & merged by {reviewer} at {timestamp}
Merge strategy: {squash|merge|rebase}
```
Commit: `git add spdd/review/{filename} && git commit -m "chore({KEY}): record merge decision in review artefact"`

**Transition Jira:**
Call `mcp__atlassian__getTransitionsForJiraIssue` with cloudId and issueIdOrKey. Find the transition whose name contains "Done" (case-insensitive). Call `mcp__atlassian__transitionJiraIssue` with that transition ID. If no "Done" transition found: skip silently, note in summary.

**Add Jira comment:**
Call `mcp__atlassian__addCommentToJiraIssue`:
```
cloudId: {cloudId}
issueIdOrKey: {KEY}
commentBody: |
  ✅ PR merged · Score: {score}/100 · Reviewer: {git user.name}
  Review artefact: spdd/review/{filename}
contentFormat: markdown
```

Display: "Done. Branch merged. Jira → Done."

---

**Path [2] — Request Changes**

Prompt the reviewer:
```
Describe the changes needed (you may reference finding numbers from the review package above):
```

Wait for free-text input.

Post a GitHub review:
```bash
gh pr review {PR_NUMBER} --repo {owner}/{repo} --request-changes --body "{reviewer feedback text}"
```

**Update artefact:** Append to `## Decision`:
```
Changes requested by {reviewer} at {timestamp}
Feedback: {feedback text}
```
Commit: `git add spdd/review/{filename} && git commit -m "chore({KEY}): record changes-requested decision in review artefact"`

**Add Jira comment:**
```
cloudId: {cloudId}
issueIdOrKey: {KEY}
commentBody: |
  🔄 Changes requested · Reviewer: {git user.name}
  {feedback text (first 200 chars if longer)}
contentFormat: markdown
```

Jira status: leave in "In Review" — do NOT transition.

Ask: "Find another reviewer? (y/n)"
- If yes: add a further Jira comment: "Awaiting reassignment to another reviewer." PR stays open.
- If no: no further action.

Display: "Review submitted. Developer has been notified via PR."

---

**Path [3] — Reject / Close PR**

> **Warning:** This will permanently close PR #{PR_NUMBER} and transition {KEY} back to In Progress. This cannot be undone from within this skill.

Ask: "Type 'yes' to confirm close, or anything else to cancel:"

Only proceed if input is exactly `yes`.

Prompt: "Reason for closing:"

Wait for free-text input.

Execute:
```bash
gh pr close {PR_NUMBER} --repo {owner}/{repo} --comment "{reason text}"
```

**Update artefact:** Append to `## Decision`:
```
Rejected & PR closed by {reviewer} at {timestamp}
Reason: {reason text}
```
Commit: `git add spdd/review/{filename} && git commit -m "chore({KEY}): record rejection decision in review artefact"`

**Transition Jira:** Find transition whose name contains "In Progress" (case-insensitive). Call `mcp__atlassian__transitionJiraIssue`. If not found: skip silently.

**Add Jira comment:**
```
cloudId: {cloudId}
issueIdOrKey: {KEY}
commentBody: |
  ❌ PR closed · Reviewer: {git user.name}
  Reason: {reason text}
contentFormat: markdown
```

Display: "PR closed. Jira → In Progress."

---

## Guardrails

- **Never merge without explicit reviewer confirmation** — score is advisory only. A GREEN score does not mean auto-merge.
- **Save review artefact (Step 6) before any merge or close** — if the commit fails, do not proceed with merge/close.
- **Never auto-resolve merge conflicts** — surface the error verbatim. Stop.
- **Quote Jira AC text verbatim** in the artefact coverage table — do not paraphrase.
- **Path [3] (Reject) requires reviewer to type 'yes'** — menu selection alone is not sufficient confirmation.
- **Canvas compliance check is best-effort** — if canvas file not found, skip and warn once. Do not halt.
- **Do not start the dev server** until the reviewer has confirmed they want to do manual testing (Step 5a).
- **Seed commands that modify data require explicit reviewer confirmation** — never run automatically.
