# Report Register Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superteam:superteam-driven-development (recommended) or superteam:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every superteam role reports at the register of its real-world counterpart, under one named pattern, "intent down, exceptions up": briefs carry goal, done-criteria and constraints; reports lead with the answer in the audience's vocabulary, SBAR-shaped, and only decision-critical items cross a level unsummarised.

**Architecture:** One doc page holds the pattern, the register table and the sources. Two levers apply it: a closing `## Report register` section in each `agents/*.md` (the IC lever, because output styles never reach subagents or teammates, verified on the output-styles doc 2026-09-09), and a plugin output style in `output-styles/` with `force-for-plugin: true` (the lead lever). The SDD spawn prompts echo the IC shape in one line each. One test asserts both levers exist.

**Tech Stack:** Markdown; `bin/superteam-test`; `claude plugin validate .`

**Spec:** The lead-box brief of 2026-09-09 (register table and mechanics quoted below).

## Global Constraints

- Voice: "your human partner", never "the user". Cite sources only as named in the brief: mission command / commander's intent and CCIR (ADP 6-0), SBAR handoff, Minto's Pyramid Principle, DDD bounded-context language, Anthropic's multi-agent research post.
- Commit trailer: `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>` and `Claude-Session: https://claude.ai/code/session_01W77dwNzwuaSbp6LxsaR7WW`; commit bodies cite `source: <file>#<section>`.
- `bin/superteam-test` 0 failed; `claude plugin validate .` passes.
- Output-style facts (docs, 2026-09-09): plugin styles live in `output-styles/`, auto-discovered; frontmatter fields are `name`, `description`, `keep-coding-instructions`, `force-for-plugin`; a style's text is sent with every request; `force-for-plugin` overrides the user's `outputStyle` for every session with the plugin enabled; styles apply to the main conversation and forks only, never to subagents or teammates; style files are read at startup, so a restart is needed.
- The register table (verbatim from the brief; the doc page carries it, every other task derives from it):

| Role | Audience | Register | Report shape |
|---|---|---|---|
| ICs: implementer, integrator, researcher, writer, reviewer, skeptic | the team lead (PM) | code specifics: file:line, diff, test output, merge sha | S what changed; B evidence; A verdict/severity; R merge / fix / decision needed |
| team lead (PM) | the lead above or the human | domain terms: user outcome, decisions taken, risks, blockers | done/not done in one line; decisions taken; open decisions for the level above; artifact refs, never diffs |
| lateral (IC↔IC, PM↔PM) | peer | the peer's own vocabulary | free-form with artifact refs |

---

### Task 1: Pattern doc and README pointer

**Files owned:** `docs/intent-down-exceptions-up.md`, `README.md`
**Depends on:** none
**Model tier:** standard

- [ ] **Step 1: Create `docs/intent-down-exceptions-up.md`** with these sections, in order, no others:
  1. `# Intent down, exceptions up` — two paragraphs: what the pattern is (downward: goal, done-criteria, constraints, never method; upward: answer first, audience's vocabulary, SBAR, only decision-critical items cross a level unsummarised), and why (a lead that reads diffs stops leading; an IC that reports in domain terms hides the evidence).
  2. `## Register table` — the table from Global Constraints, verbatim.
  3. `## Sources` — one bullet each: mission command / commander's intent and CCIR (ADP 6-0) for intent down and what crosses a level; SBAR handoff for the report shape; Minto's Pyramid Principle for answer first; DDD bounded-context language for lateral talk; Anthropic's multi-agent research post ("How we built our multi-agent research system") for "each subagent gets an objective and an output format, passes lightweight references back". Name each, one line on what it contributes; no URLs invented — omit the URL where unsure.
  4. `## The two levers` — ICs: a closing `## Report register` section in each `agents/*.md`, because output styles apply to the main conversation and forks only, never to subagents or teammates (docs, output-styles page). Team lead: the plugin output style `output-styles/superteam-lead.md`, `force-for-plugin: true`, sent with every request.
  5. `## Caveat: force-for-plugin` — it overrides the user's own `outputStyle` in every session with the plugin enabled, so the style carries Concise's core (lead with the result, no preamble, no recap, plain prose for simple answers, full detail on request, never trade correctness for brevity) and nothing is lost for sessions that ran Concise; a restart is needed because style files are read at startup.
- [ ] **Step 2: README pointer.** Under `### Agents`, after the paragraph beginning "A role's `skills:` frontmatter", add: `Every role reports in its own register — see [docs/intent-down-exceptions-up.md](docs/intent-down-exceptions-up.md); the team lead's register ships as the plugin output style \`superteam-lead\` (forced on while the plugin is enabled).`
- [ ] **Step 3: Commit** — "Docs: intent down, exceptions up — register table and the two levers" with `source: docs/intent-down-exceptions-up.md`.

---

### Task 2: Lead output style

**Files owned:** `output-styles/superteam-lead.md`
**Depends on:** none
**Model tier:** standard

- [ ] **Step 1: Create the file**, verbatim:

```markdown
---
name: superteam-lead
description: Team-lead register for superteam — answer first, domain terms, decisions up, intent down; carries Concise's core
keep-coding-instructions: true
force-for-plugin: true
---

You lead a superteam. Two rules shape every message you send.

**Reports go up in your audience's vocabulary.** Your audience is the lead above you or your human partner. Lead with the answer: done or not done in one line. Then the decisions you took, the decisions that are theirs to make, and the risks or blockers. Point at artifacts (a commit, a file, a report path); never paste a diff, test output, or a narration of the tools you used. Only what changes their decision crosses the level unsummarised.

**Briefs go down as intent.** When you brief an IC, state the goal, the done-criteria and the constraints. Never the method; the IC owns how.

Keep responses short by default: lead with the result, skip preamble and recap, plain prose for simple answers, headers and lists only when they carry structure. Answer in full when asked for detail. Never trade correctness for brevity: error reports, failing output, security warnings and confirmations for destructive actions keep their full content.
```

- [ ] **Step 2: Verify** — `claude plugin validate .` passes; `grep -c '^\(name\|description\|keep-coding-instructions\|force-for-plugin\):' output-styles/superteam-lead.md` prints `4`.
- [ ] **Step 3: Commit** — "Output style: superteam-lead (team-lead register, forced while the plugin is enabled)" with `source: output-styles/superteam-lead.md`.

---

### Task 3: IC report register in the six agents and the four SDD prompts

**Files owned:** `agents/implementer.md`, `agents/writer.md`, `agents/integrator.md`, `agents/researcher.md`, `agents/reviewer.md`, `agents/skeptic.md`, `skills/superteam-driven-development/implementer-prompt.md`, `skills/superteam-driven-development/task-reviewer-prompt.md`, `skills/superteam-driven-development/task-standards-prompt.md`, `skills/superteam-driven-development/re-review-prompt.md`
**Depends on:** none
**Model tier:** standard

- [ ] **Step 1: Append a closing section to each agent file** (last section in the file, after everything else). The section states audience and register and maps the file's existing report shape onto SBAR; it never adds a second template. Implementer and writer get this, verbatim:

```
## Report register

Your audience is the team lead; write in code specifics — `file:line`, the diff stat, test output, a commit — never in domain summary. Your `## Report` shape above is the report, read as SBAR: what changed and where (situation), the diff and test output (background), your self-review and anything unresolved (assessment), and your status line — done, blocked, or needs context — is the recommendation. Answer first: the status line leads. A question to another IC is lateral: their vocabulary, an artifact reference, no report.
```

  Integrator gets this, verbatim:

```
## Report register

Your audience is the team lead; write in code specifics — the merge sha, the `Tests:` line, the conflict you resolved — never in domain summary. Your completion message is the report, read as SBAR: what merged (situation), the suite output (background), clean or blocked (assessment), and the next action — bump, hold, or decision needed — is the recommendation. Answer first: merged or blocked leads.
```

  Researcher gets this, verbatim:

```
## Report register

Your audience is the team lead; write in code specifics — `file:line`, URL + section — never in domain summary. Your Conclusion / Evidence / Open / Findings file shape is the report, read as SBAR: the conclusion is situation and assessment in one, the evidence is background, and Open — what would settle it — is the recommendation. Answer first: the conclusion leads. A message to a peer investigator is lateral: their vocabulary, an artifact reference, no report.
```

  Reviewer gets this, verbatim:

```
## Report register

Your audience is the team lead; write in code specifics — `file:line`, severity, the one test you ran — never in domain summary. The shape the rubric prompt defines is the report: findings are the situation, their evidence the background, severity the assessment, the verdict line the recommendation. A question to the implementer is lateral: their vocabulary, an artifact reference, no report.
```

  Skeptic gets this, verbatim:

```
## Report register

Your audience is the team lead; write in code and design specifics — the part, the file, the coupling — never in domain summary. Your numbered kill/keep/shrink list is the report: each verdict is the assessment, its one-line why the background, "Cut this first" the recommendation.
```

- [ ] **Step 2: Echo the shape in the SDD prompts.** In `implementer-prompt.md`, change the cadence line `8. Report back` to `8. Report back — SBAR: what changed, evidence, your assessment, merge / fix / decision needed`. In each of `task-reviewer-prompt.md`, `task-standards-prompt.md`, `re-review-prompt.md`, add one line immediately before the prompt's final report-shape instruction: `Register: code specifics for the team lead — file:line, diff, severity — answer first; see agents/reviewer.md "Report register".`
- [ ] **Step 3: Verify** — `for f in agents/*.md; do grep -q '^## Report register' $f || echo MISSING $f; done` prints nothing; `bash tests/claude-code/test-agent-roster.sh` and `bash tests/claude-code/test-dispatch-template.sh` pass.
- [ ] **Step 4: Commit** — "Agents: closing Report register section on every seat; SDD prompts echo the SBAR shape" with `source: agents/*.md#report-register`.

---

### Task 4: Tests

**Files owned:** `tests/claude-code/test-agent-roster.sh`, `tests/claude-code/test-output-style.sh`, `bin/superteam-test`
**Depends on:** Task 2, Task 3
**Model tier:** cheap

- [ ] **Step 1: Roster assertion.** In the `for role in implementer writer reviewer integrator researcher skeptic` loop of `test-agent-roster.sh`, add after the claim-rule line: `grep -q '^## Report register' "$f" && pass "agents/$role.md closes with Report register" || fail "agents/$role.md closes with Report register"`. Task 3 is merged before this runs, so it passes.
- [ ] **Step 2: Style test.** Create `tests/claude-code/test-output-style.sh` in the roster test's style (same `pass`/`fail` helpers from `test-helpers.sh`, `set -euo pipefail`, exit non-zero on any fail): assert `output-styles/superteam-lead.md` exists and each of `name:`, `description:`, `keep-coding-instructions: true`, `force-for-plugin: true` appears once at line start inside the frontmatter (between the first two `---` lines). Make it executable.
- [ ] **Step 3: Runner row.** Add `tests/claude-code/test-output-style.sh|` after the roster row in `bin/superteam-test`.
- [ ] **Step 4: Commit** — "Tests: every agent closes with Report register; output style frontmatter" with `source: tests/claude-code/test-output-style.sh`.

---

### Task 5: Bump (lead)

**Files owned:** the nine version manifests
**Depends on:** Task 1, Task 2, Task 3, Task 4
Bump 7.2.0 → 7.3.0 (new component: an output style); `bin/superteam-test`; `claude plugin validate .`; merge lane into main.
