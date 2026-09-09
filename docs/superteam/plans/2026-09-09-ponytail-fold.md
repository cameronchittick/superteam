# Ponytail Fold Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superteam:superteam-driven-development (recommended) or superteam:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move the useful "lazy senior dev" judgement from the Ponytail plugin (4.9.0, MIT) into the superteam seats that judge — skeptic, standards reviewer, implementer — and nothing else.

**Architecture:** Three prose edits to existing behaviour-shaping files, one attribution/changelog commit by the lead. No new skills, hooks, modes, commands or servers. The ladder is design-time judgement (skeptic); the reviewer gets three named findings in the smell-baseline shape; the implementer gets two lines of habit.

**Tech Stack:** Markdown agent and skill files; `bin/superteam-test`; `claude plugin validate .`

**Spec:** The lead-b brief of 2026-09-09 (quoted in each task). Cameron's finding, binding on every task: run as a session-wide persona, Ponytail's "reuse the pattern already here / shortest diff wins" amplified existing bad grooves instead of questioning them. So the ladder lives only where a seat can also rule the existing pattern is the thing to kill.

## Global Constraints

- Edit only the files each task owns; the four Ponytail parts NOT ported are: the mode hook/persona, level switching, statusline and mode tracker, the audit/debt/gain/review commands, the MCP server. Nothing in the plugin may reference or depend on Ponytail at runtime.
- Keep superteam voice: "your human partner", never "the user"; no Ponytail persona wording ("lazy", "3am" is already the skeptic's own), no "shortest diff wins" anywhere.
- Commit trailer: `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>` and `Claude-Session: https://claude.ai/code/session_01W77dwNzwuaSbp6LxsaR7WW`; commit bodies cite `source: <file>#<section>`.
- Tests: `bin/superteam-test` green (16 pass / 0 fail on this host; 2 host skips allowed). `claude plugin validate .` passes.
- Marker convention for a deliberate corner cut: a code comment beginning `ceiling:` that names the ceiling and the upgrade path, e.g. `# ceiling: global lock; per-account locks if throughput matters`. Task 2 documents it; Task 3 uses it.

---

### Task 1: Skeptic ladder

**Files owned:** `agents/skeptic.md`
**Depends on:** none
**Model tier:** standard

**Files:**
- Modify: `agents/skeptic.md` (step 4, "Ask the four questions")

**Interfaces:**
- Consumes: nothing
- Produces: nothing other tasks rely on

- [ ] **Step 1: Replace step 4** so it reads, verbatim:

```
4. Ask these questions of every part of the design, in this order, and
   stop at the first that settles it:
   - Does this need to exist at all?
   - What breaks at 3am?
   - What would you delete?
   - Where is the hidden coupling?
   - Is it already in this codebase? A helper, type or pattern that already
     lives here is the first candidate — and also a candidate to kill:
     design time is the only place "reuse what is here" is safe, because
     you may rule the existing pattern is the thing to cut.
   - Does the standard library do it?
   - Does a native platform feature cover it? `<input type="date">` over a
     picker library, CSS over JS, a DB constraint over app code.
   - Does an already-installed dependency solve it? Never a new one for
     what a few lines can do.
```

- [ ] **Step 2: Run the roster test and validate**

Run: `bash tests/claude-code/test-agent-roster.sh && claude plugin validate .`
Expected: all PASS lines for `agents/skeptic.md`, validation passed.

- [ ] **Step 3: Commit**

```bash
git add agents/skeptic.md
git commit -m "Skeptic: add the reuse/stdlib/native/installed ladder to step 4

source: agents/skeptic.md#4"
```

---

### Task 2: Standards findings

**Files owned:** `skills/requesting-code-review/smell-baseline.md`
**Depends on:** none
**Model tier:** standard

**Files:**
- Modify: `skills/requesting-code-review/smell-baseline.md`

**Interfaces:**
- Consumes: nothing
- Produces: the `ceiling:` marker convention that Task 3 cites

- [ ] **Step 1: Extend Speculative Generality** with one-line examples, so the bullet reads verbatim:

```
- **Speculative Generality** — abstraction, parameters, or hooks added for needs the spec doesn't have: an interface with one implementation, a factory for one product, config for a value that never changes. → delete it; inline back until a real need shows.
```

- [ ] **Step 2: Add a section after the Fowler list and before `## Attribution`**, verbatim:

```
## Ladder findings

Three more, same shape, from the Ponytail plugin's ladder (MIT, see Attribution). Same two rules bind them: the repo overrides, and each is a judgement call.

- **New Dependency** — a package added for what a few lines, the standard library, a native platform feature, or an already-installed dependency does. → remove it; use what is already there.
- **Symptom Fix** — a guard or special case added in one caller when the shared function every caller routes through is where the defect lives. → move the fix into the shared function; delete the caller-side guard.
- **Unmarked Ceiling** — a deliberate corner cut (a global lock, an O(n²) scan, a naive heuristic) with no comment naming the ceiling and the upgrade path. → add a `ceiling:` comment: `# ceiling: global lock; per-account locks if throughput matters`. A cut with no honest ceiling is a defect, not a shortcut.
```

- [ ] **Step 3: Extend `## Attribution`** by appending one sentence:

```
The three ladder findings and the `ceiling:` marker are adapted from the [Ponytail](https://github.com/DietrichGebert/ponytail) plugin 4.9.0 (MIT, Copyright 2026 DietrichGebert). See LICENSE.
```

- [ ] **Step 4: Verify and commit**

Run: `grep -c "^- \*\*" skills/requesting-code-review/smell-baseline.md`
Expected: `15`

```bash
git add skills/requesting-code-review/smell-baseline.md
git commit -m "Smell baseline: New Dependency, Symptom Fix, Unmarked Ceiling; Speculative Generality examples

source: skills/requesting-code-review/smell-baseline.md#ladder-findings"
```

---

### Task 3: Implementer habits

**Files owned:** `agents/implementer.md`
**Depends on:** none
**Model tier:** cheap

**Files:**
- Modify: `agents/implementer.md` (step 5, work cadence)

**Interfaces:**
- Consumes: the `ceiling:` convention (Global Constraints)
- Produces: nothing

- [ ] **Step 1: Insert one item into step 5** between (a) and (b), relettering (b)–(g) to (c)–(h), verbatim:

```
   (b) Before writing a helper, util or type, grep for one that already
       exists. A bug fix goes at the root cause, after reading every
       caller of the function you are about to touch. A deliberate corner
       cut gets a comment beginning `ceiling:` that names the ceiling and
       the upgrade path.
```

- [ ] **Step 2: Fix the cross-reference** in (h) (was (g)) — none needed; it names no letters. Confirm with `grep -n "(b)\|(g)\|(h)" agents/implementer.md`.

- [ ] **Step 3: Run the roster test and commit**

Run: `bash tests/claude-code/test-agent-roster.sh`
Expected: all PASS for `agents/implementer.md`.

```bash
git add agents/implementer.md
git commit -m "Implementer: grep before writing a helper, fix at the root cause, mark ceilings

source: agents/implementer.md#5"
```

---

### Task 4: Attribution, changelog, bump (lead)

**Files owned:** `LICENSE`, `README.md`, `CHANGELOG.md`, the nine version manifests
**Depends on:** Task 1, Task 2, Task 3
**Model tier:** cheap (lead does it: deletion-free, copy-exact)

- [ ] LICENSE: append a section `## skills/requesting-code-review/smell-baseline.md (ladder findings), agents/skeptic.md (ladder), agents/implementer.md (ceiling marker)` with the Ponytail MIT text (Copyright (c) 2026 DietrichGebert), same shape as the Matt Pocock section.
- [ ] README.md line 307: append one sentence: "The design-time ladder in the skeptic, the three ladder findings in the smell baseline and the `ceiling:` marker are adapted from the [Ponytail](https://github.com/DietrichGebert/ponytail) plugin (MIT)."
- [ ] Create `CHANGELOG.md` with `# Changelog` and one entry: `## 7.2.0 — 2026-09-09` / `- Fold the Ponytail (MIT, DietrichGebert) ladder into the seats that judge: skeptic step 4, three smell-baseline findings (New Dependency, Symptom Fix, Unmarked Ceiling) with the \`ceiling:\` marker, two implementer habits. No mode, persona, commands or server ported.`
- [ ] Bump all nine manifests 7.1.3 → 7.2.0; `bin/superteam-test`; `claude plugin validate .`; commit.
