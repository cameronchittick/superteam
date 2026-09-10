---
name: writing-plans
description: Use when you have a spec or requirements for a multi-step task, before touching code
---

# Writing Plans

## Overview

Write comprehensive implementation plans assuming the engineer has zero context for our codebase and questionable taste. Document everything they need to know: which files to touch for each task, code, testing, docs they might need to check, how to test it. Give them the whole plan as bite-sized tasks. DRY. YAGNI. TDD. Frequent commits.

Assume they are a skilled developer, but know almost nothing about our toolset or problem domain. Assume they don't know good test design very well.

**Announce at start:** "I'm using the writing-plans skill to create the implementation plan."

**Context:** If working in an isolated worktree, it should have been created via the `superteam:using-git-worktrees` skill at execution time.

**Save plans to:** `docs/superteam/plans/YYYY-MM-DD-<feature-name>.md`
- (User preferences for plan location override this default)

## Scope Check

If the spec covers multiple independent subsystems, it should have been broken into sub-project specs during brainstorming. If it wasn't, suggest breaking this into separate plans — one per subsystem. Each plan should produce working, testable software on its own.

## File Structure

Before defining tasks, map out which files will be created or modified and what each one is responsible for. This is where decomposition decisions get locked in.

- Design units with clear boundaries and well-defined interfaces. Each file should have one clear responsibility.
- You reason best about code you can hold in context at once, and your edits are more reliable when files are focused. Prefer smaller, focused files over large ones that do too much.
- Files that change together should live together. Split by responsibility, not by technical layer.
- In existing codebases, follow established patterns. If the codebase uses large files, don't unilaterally restructure - but if a file you're modifying has grown unwieldy, including a split in the plan is reasonable.

This structure informs the task decomposition. Each task should produce self-contained changes that make sense independently.

## Task Right-Sizing

A task is the smallest unit that carries its own test cycle and is worth a
fresh reviewer's gate. When drawing task boundaries: fold setup,
configuration, scaffolding, and documentation steps into the task whose
deliverable needs them; split only where a reviewer could meaningfully
reject one task while approving its neighbor. Each task ends with an
independently testable deliverable.

## Bite-Sized Task Granularity

**Each step is one action (2-5 minutes):**
- "Write the failing test" - step
- "Run it to make sure it fails" - step
- "Implement the minimal code to make the test pass" - step
- "Run the tests and make sure they pass" - step
- "Commit" - step

## Plan Document Header

**Every plan MUST start with this header:**

```markdown
# [Feature Name] Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superteam:superteam-driven-development to implement this plan task-by-task. On a harness without agent teams, superteam:executing-plans is the fallback. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** [One sentence describing what this builds]

**Architecture:** [2-3 sentences about approach]

**Tech Stack:** [Key technologies/libraries]

**Spec:** [path to the spec/design doc this plan implements — the plan
argues from the spec, so the spec travels with it; executors read both]

**Integration:** trunk | lane/<name> — a lane only when two or more tasks merge before trunk

## Global Constraints

[The spec's project-wide requirements — version floors, dependency limits,
naming and copy rules, platform requirements — one line each, with exact
values copied verbatim from the spec. Every task's requirements implicitly
include this section.]

- Use the terms in `CONTEXT.md` for task names, identifiers, file names and tests; do not coin synonyms. A term the plan needs but the glossary lacks goes back to your human partner via superteam:domain-modeling before the plan is finished — the plan never edits `CONTEXT.md`.

---
```

## Task Structure

````markdown
### Task N: [Component Name]

**Files owned:** `exact/path/to/file.py`, `tests/exact/path/to/test.py`
**Depends on:** none (or: Task 2, Task 3)
**Model tier:** cheap | standard | most capable
**Isolation:** trunk | branch | worktree | provisioned

**Files:**
- Create: `exact/path/to/file.py`
- Modify: `exact/path/to/existing.py:123-145`
- Test: `tests/exact/path/to/test.py`

**Interfaces:**
- Consumes: [what this task uses from earlier tasks — exact signatures]
- Produces: [what later tasks rely on — exact function names, parameter
  and return types. A task's implementer sees only their own task; this
  block is how they learn the names and types neighboring tasks use.]

- [ ] **Step 1: Write the failing test**

```python
def test_specific_behavior():
    result = function(input)
    assert result == expected
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/path/test.py::test_name -v`
Expected: FAIL with "function not defined"

- [ ] **Step 3: Write minimal implementation**

```python
def function(input):
    return expected
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/path/test.py::test_name -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add tests/path/test.py src/path/file.py
git commit -m "feat: add specific feature"
```
````

**The four header lines.** A lead hands each task to one IC, so
`**Files owned:**` lists every file the task creates or edits —
no two tasks that can run concurrently may share a file, or their branches
collide at merge. `Files owned:` plus the `Interfaces:` block are the task's
seam — the boundary its implementer tests at. When two tasks must share a
file, the later one lists the earlier one in `Depends on:` — that line
becomes a `blockedBy` edge on the
task list and is what lets the `task-created-check` hook accept the overlap;
an overlap with no edge is rejected at creation (agent-teams.md, Avoid file
conflicts). `**Depends on:**` names the tasks whose output this one
consumes, which is what decides dispatch order (dependents wait; the rest
run in parallel). `**Model tier:**` follows the reasoning in
superteam:superteam-driven-development's Model Selection — cheap for 1-2 files
with a complete spec, standard for multi-file integration, most capable for
design judgment — and drives what each task costs.

**Isolation: format.** Write `Isolation: trunk`, `Isolation: branch`,
`Isolation: worktree` or `Isolation: provisioned` — one word, in the header.
Trunk is the default and what a missing line means: the IC commits straight
on `<base>` in the lead's own checkout and the lead reads the commits after
they land. Choose branch only when a review seat must sit between the work
and trunk or a second seat is live; choose worktree only when this task will
be written at the same time as another task in the same repo; choose
provisioned only when the task needs a second running dev server or
database. A plan with two or more tasks merging before trunk names its
lane in a header line `**Integration:** lane/<name>`; otherwise
`**Integration:** trunk`. The rule and its evidence are in
docs/isolation-tiers.md.

**Depends on: format.** Write it as `Depends on: Task 2, Task 3` or
`Depends on: none` — always task numbers, one line, in the header where
it already sits. On Claude Code, superteam-driven-development's live
ledger parses this line and wires each dependency into `addBlockedBy` on
the shared task list, so the exact format is what makes a task
machine-mappable, not just human-readable.

**Task subjects on that list.** Each plan task becomes `Task N: <step>
[role]` — step in {implement, review spec, review standards (both only when the sizing seated a reviewer), merge (worktree tier only), fix <round>, review <round>};
N is unique for the life of the list, never restarting at 1. Everything else
is an imperative verb phrase — full rules in superteam-driven-development.

## No Placeholders

Every step must contain the actual content an engineer needs. These are **plan failures** — never write them:
- "TBD", "TODO", "implement later", "fill in details"
- "Add appropriate error handling" / "add validation" / "handle edge cases"
- "Write tests for the above" (without actual test code)
- "Similar to Task N" (repeat the code — the engineer may be reading tasks out of order)
- Steps that describe what to do without showing how (code blocks required for code steps)
- References to types, functions, or methods not defined in any task

## Self-Review

After writing the complete plan, look at the spec with fresh eyes and check the plan against it. This is a checklist you run yourself — not a subagent dispatch.

**1. Spec coverage:** Skim each section/requirement in the spec. Can you point to a task that implements it? List any gaps.

**2. Placeholder scan:** Search your plan for red flags — any of the patterns from the "No Placeholders" section above. Fix them.

**3. Type consistency:** Do the types, method signatures, and property names you used in later tasks match what you defined in earlier tasks? A function called `clearLayers()` in Task 3 but `clearFullLayers()` in Task 7 is a bug.

If you find issues, fix them inline. No need to re-review — just fix and move on. If you find a spec requirement with no task, add the task.

Dispatch `superteam:skeptic` on the task breakdown when the sizing finds a design choice worth an objection before building (docs/isolation-tiers.md, Sizing the work); the plan-document reviewer is `superteam:reviewer` (see `./plan-document-reviewer-prompt.md`).

## Execution Handoff

After saving the plan, hand it off:

**"Plan complete and saved to `docs/superteam/plans/<filename>.md`. Next:
superteam:superteam-driven-development (REQUIRED SUB-SKILL). On a harness
without agent teams, superteam:executing-plans is the fallback."**

You act as lead: one IC per task, isolated per its tier, a task review after
each, and the integrator merges.
