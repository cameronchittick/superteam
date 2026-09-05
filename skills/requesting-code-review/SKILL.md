---
name: requesting-code-review
description: Use when completing tasks, implementing major features, or before merging to verify work meets requirements
---

# Requesting Code Review

Dispatch code reviewer subagents to catch issues before they cascade. Each reviewer gets precisely crafted context for evaluation — never your session's history.

The review runs along two axes, as two parallel subagents that never see each other's context:

- **Standards** — does the code conform to this repo's documented coding standards (plus the [smell baseline](smell-baseline.md))?
- **Spec** — does the code faithfully implement the originating spec, plan, or task brief?

**Core principle:** Review early, review often.

## When to Request Review

**Mandatory:**
- After each task in subagent-driven development
- After completing major feature
- Before merge to main

**Optional but valuable:**
- When stuck (fresh perspective)
- Before refactoring (baseline check)
- After fixing complex bug

## How to Request

**1. Pin the fixed point:**

The fixed point is whatever the caller named — a commit SHA, branch, tag, `origin/main`, `HEAD~5`. If nothing was named, ask your human partner. Verify it BEFORE dispatching anything: a bad ref or an empty diff should fail here, not inside two parallel subagents.

```bash
BASE_SHA=$(git rev-parse <fixed-point>) || exit 1   # must resolve
HEAD_SHA=$(git rev-parse HEAD)
git diff --stat $BASE_SHA...HEAD | grep -q . || exit 1   # must be non-empty (three-dot: against the merge-base)
git log $BASE_SHA..HEAD --oneline
```

**2. Identify the spec source**, in this order:

1. A path the caller passed
2. The brainstorming spec under `docs/superteam/specs/` or the writing-plans plan under `docs/superteam/plans/` matching the branch or feature
3. The task brief
4. Ask your human partner

If there is none, the Spec axis is skipped and the aggregated report says so.

**3. Identify the standards sources:**

Whatever the repo documents — `CONTRIBUTING.md`, `CODING_STANDARDS.md`, `CLAUDE.md`, `AGENTS.md` — PLUS [smell-baseline.md](smell-baseline.md) pasted in full into the Standards prompt. The subagent has no other access to it. The baseline applies even when the repo documents nothing; a documented repo standard overrides it, and every smell is a labelled judgement call, never a hard violation.

**4. Dispatch BOTH reviewers in one message:**

Two parallel `superteam:reviewer` subagents — one filling [standards-reviewer.md](standards-reviewer.md), one filling [spec-reviewer.md](spec-reviewer.md). Same `DESCRIPTION`, `BASE_SHA`, `HEAD_SHA` for both; the Standards one gets the standards files and the baseline, the Spec one gets the spec. The agent carries its model; override it only with a written reason (the final whole-branch review under superteam:team-driven-development is one: `model: opus`). On a harness without the plugin agent, use its generic subagent with the same prompt.

**5. Aggregate:**

Present the two reports under `## Standards` and `## Spec` headings, verbatim or lightly cleaned. Do NOT merge or rerank findings across axes — the separation is deliberate (see _Why two axes_). End with one line: findings per axis and the worst issue within each axis. Never pick a single winner across axes; that is the reranking the separation exists to prevent.

**6. Act on feedback:**
- Fix Critical issues immediately
- Fix Important issues before proceeding
- Note Minor issues for later
- Push back if reviewer is wrong (with reasoning)

## Why two axes

A change can pass one axis and fail the other:

- Code that follows every standard but implements the wrong thing → **Standards pass, Spec fail.**
- Code that does exactly what the spec/plan asked but breaks the project's conventions → **Spec pass, Standards fail.**

Reporting them separately stops one axis from masking the other.

**In team-driven-development:** the per-task reviewer stays one teammate (its prompt already carries both parts). This two-axis dispatch is for standalone review and the Final whole-branch review.

## Example

```
[Just completed Task 2: Add verification function]

You: Let me request code review before proceeding.

BASE_SHA=$(git rev-parse a7981ec)          # resolves
git diff --stat a7981ec...HEAD | grep -q .  # non-empty
Spec source: Task 2 from docs/superteam/plans/deployment-plan.md
Standards: CLAUDE.md + smell-baseline.md

[Dispatch both, one message]
  standards-reviewer.md  DESCRIPTION: Added verifyIndex() and repairIndex() with 4 issue types
                         BASE_SHA: a7981ec  HEAD_SHA: 3df7661
                         STANDARDS_FILES: CLAUDE.md   SMELL_BASELINE: <pasted>
  spec-reviewer.md       DESCRIPTION: (same)  BASE_SHA/HEAD_SHA: (same)
                         SPEC: docs/superteam/plans/deployment-plan.md, Task 2

## Standards
  Strengths: Clean architecture, real tests
  Important: Missing progress indicators (CLAUDE.md "long ops report progress")
  Minor: possible Primitive Obsession — magic number (100) for reporting interval (judgement call)
  Assessment: With fixes

## Spec
  Missing: none
  Extra: repairIndex() --dry-run flag — plan line "repair in place" never asked for it
  Assessment: With fixes

Standards: 2 findings, worst Important (progress indicators). Spec: 1 finding, worst Extra (--dry-run).

You: [Fix progress indicators; confirm --dry-run with your human partner or drop it]
[Continue to Task 3]
```

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "I'll just review the diff myself instead of dispatching a reviewer" | You're the coordinator — reviewing the diff inline burns the context window you need to keep driving the work. Dispatch a reviewer subagent: the diff and the evaluation live in its context, and only the findings come back to you. |
| "The reviewer needs my whole session history to understand the change" | Hand it precisely crafted context, never your session's history. That keeps the reviewer on the work product, not your thought process. |

## Red Flags

**Never:**
- Skip review because "it's simple"
- Ignore Critical issues
- Proceed with unfixed Important issues
- Argue with valid technical feedback

**If reviewer wrong:**
- Push back with technical reasoning
- Show code/tests that prove it works
- Request clarification

Templates: [standards-reviewer.md](standards-reviewer.md), [spec-reviewer.md](spec-reviewer.md), [smell-baseline.md](smell-baseline.md)
