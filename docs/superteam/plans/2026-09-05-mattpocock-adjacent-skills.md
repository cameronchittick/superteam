# Assessment: adjacent mattpocock skills (additive folds, not ports)

Source: `~/.claude/plugins/cache/mattpocock/mattpocock-skills/1.2.0/skills/engineering/` (MIT © 2026 Matt Pocock).
Brief (lead-b, 2026-09-05): per skill, port-verbatim / fold-into-existing / skip; map every cross-skill call to the superteam equivalent; drop Matt-specific plumbing; say what is added vs what already existed; one canonical home per piece of doctrine. Plan only, no build.

## Cross-skill call map (applies to every item below)

| Matt calls | Superteam equivalent |
|---|---|
| `/grilling` | superteam:brainstorming (clarifying-questions loop, one at a time) |
| `/domain-modeling`, `CONTEXT.md`, ADRs | superteam:domain-modeling (6.5.0). **Superteam rule is stricter:** Matt writes `CONTEXT.md` lazily; here only the brainstorming HITL conversation writes it, and only after offering. Every fold keeps that rule. |
| `docs/agents/issue-tracker.md`, `/setup-matt-pocock-skills`, `.out-of-scope/` | none — drop. Spec source becomes brainstorming spec (`docs/superteam/specs/`), writing-plans plan, or the TDD task brief. |
| Agent-tool parallel sub-agents | superteam:dispatching-parallel-agents; reviewers are teammates per team-driven-development |
| `/code-review` (from tdd) | superteam:requesting-code-review |
| `/wayfinder` | none |

## Verdicts

### 1. code-review → FOLD into requesting-code-review (+ one line each in task-reviewer-prompt and receiving-code-review)

**Already existed:** requesting-code-review dispatches one reviewer with a plan/requirements section and a quality checklist; team-driven-development's task-reviewer-prompt already splits Part 1 Spec Compliance (missing / extra / misunderstood — same three findings as Matt's Spec axis) from Part 2 Code Quality, in one reviewer.

**Added (the doctrine Cameron wants):**
- Two axes run as **separate parallel subagents** and reported under `## Standards` / `## Spec` **without reranking across axes**; one-line summary gives worst-per-axis, never a single winner. "Why two axes" paragraph ported.
- **Smell baseline**: the 12 Fowler smells (what → fix) as a new file `skills/requesting-code-review/smell-baseline.md`, ported verbatim with attribution. Two binding rules: documented repo standard overrides baseline; every smell is a labelled judgement call ("possible Feature Envy"), never a hard violation; skip what tooling enforces.
- **Standards sources** = whatever the repo documents (CONTRIBUTING.md, CODING_STANDARDS.md, CLAUDE.md) + baseline pasted in full into the Standards prompt (the subagent has no other access to it).
- Fixed-point discipline: verify the ref resolves and diff is non-empty *before* spawning.

**Shape:** requesting-code-review SKILL.md gains a "Two-axis review" section; `code-reviewer.md` splits into `standards-reviewer.md` and `spec-reviewer.md` (existing quality checklist + calibration + output format kept and distributed across the two). Spec source order: path the caller passes → spec/plan under `docs/superteam/` matching the branch → ask; "no spec" = Spec axis skipped and stated.

**Where it applies:** the standalone skill and team-driven-development's **Final Review** (whole-branch) go two-axis. The **per-task** reviewer stays one teammate (it already carries both parts; two seats per task doubles the most frequent review cost) but Part 2 gains one line pointing at `smell-baseline.md` with the override + judgement-call rules. receiving-code-review gains one row: a baseline smell is a heuristic — evaluate it against this codebase, don't implement it because it was named.

**Canonical home:** smell baseline lives only in `smell-baseline.md`; task-reviewer-prompt links, never copies.

### 2. codebase-design → NEW SKILL `superteam:codebase-design` (doctrine port, plumbing mapped)

**Already existed:** brainstorming proposes 2-3 approaches; dispatching-parallel-agents; task-reviewer "Structure" asks for one responsibility + well-defined interface. Nothing in superteam names deep vs shallow, seams, or adapters.

**Added:**
- SKILL.md doctrine verbatim: vocabulary (module, interface, implementation, depth, seam, adapter, leverage, locality), deep vs shallow, deletion test, "interface is the test surface", testability rules, rejected framings.
- DEEPENING.md verbatim (4 dependency categories, "one adapter = hypothetical seam, two = real", replace-don't-layer tests).
- DESIGN-IT-TWICE.md folded with its plumbing mapped: the 3-4 parallel design agents become a dispatching-parallel-agents dispatch (read-only, one brief each, different constraint each); "the user" → "your human partner"; presentation + opinionated recommendation kept.

**Hooks (each one line):** brainstorming Architectural path "Propose 2-3 approaches": when the design touches module boundaries, use codebase-design vocabulary and offer design-it-twice for the chosen interface. task-reviewer-prompt Structure: "Deletion test: would removing this unit concentrate complexity or just move it? Shallow modules are a finding." writing-plans: none (Files owned/Depends on already exist; YAGNI on dependency categories there).

**Canonical home:** vocabulary lives only in codebase-design/SKILL.md; every other skill uses the terms and links.

### 3. improve-codebase-architecture → FOLD the doctrine into codebase-design; DROP the HTML report

It is a slash command (`disable-model-invocation`) whose body is 60% report plumbing (Tailwind + Mermaid CDN, temp file, `open`). Superteam already has one visual surface (brainstorming's visual companion) and a second one-off HTML generator is Matt-specific plumbing.

**Extract into codebase-design as "## Finding deepening candidates" (~25 lines):** scope before you scan (git hot spots, or the direction the human named); the five friction questions; deletion test on suspects; candidate fields (files, problem, solution, benefits in locality/leverage terms, before/after, strength Strong / Worth exploring / Speculative); top recommendation; ADR-conflict rule (surface only when friction warrants reopening). Output is a markdown report in chat or `docs/superteam/`; the Explore subagent stays (it exists here). Grilling loop → brainstorming; CONTEXT.md side effects → domain-modeling under the offer-not-write rule.

**Skipped:** HTML-REPORT.md entirely. If Cameron wants the visual, an Artifact from the markdown report is one step later and needs no skill text.

### 4. tdd → FOLD two items into test-driven-development

**Added:** (a) "read `CONTEXT.md` so test names and interface vocabulary match the domain language; respect ADRs in the area"; (b) a short **Seams** paragraph: tests live at the public interface (link codebase-design "interface is the test surface"); name the seams under test before writing the first test and confirm them with your human partner.
**Skipped:** "refactoring is not part of the loop" — contradicts superteam's REFACTOR step; superteam's tested content wins. Anti-patterns are already covered by writing-good-tests.md.

### 5. diagnosing-bugs → FOLD one line into systematic-debugging Phase 1

"Read `CONTEXT.md` (if present) for the mental model of the modules involved, and ADRs in the area." Rest skipped: systematic-debugging is the canonical home.

### 6. triage, wayfinder → SKIP

Both are issue-tracker workflows built on `docs/agents/issue-tracker.md` and `.out-of-scope/`; wayfinder has no CONTEXT.md reference at all. No superteam equivalent and the domain-modeling hook they'd carry is already in brainstorming.

### 7. grill-with-docs → SKIP

Its whole body is "run grilling with domain-modeling", which is exactly what brainstorming does since 6.5.0.

## Attribution

Every ported or folded body keeps an Attribution footer / inline credit; LICENSE already carries the MIT notice under `skills/domain-modeling` — extend that heading to list `skills/codebase-design` and `requesting-code-review/smell-baseline.md`. README Credit sentence extended.

## Tasks (on go)

- T16 (IC) code-review fold: requesting-code-review two-axis section, `smell-baseline.md`, split reviewer prompts, task-reviewer Part 2 line, receiving-code-review row, team-driven-development Final Review points at the two-axis dispatch.
- T17 (IC) `skills/codebase-design/` (SKILL.md + DEEPENING.md verbatim, DESIGN-IT-TWICE.md mapped, "Finding deepening candidates" section), brainstorming + task-reviewer one-liners, README bullet, manifest keywords.
- T18 (IC or PM) tdd two items, systematic-debugging one line, LICENSE/README attribution.
- T19 (PM) validate, hook/sdd/manifest tests, bootstrap still 60 lines, fresh `claude -p` loads `superteam:codebase-design`, bump **6.6.0** (new skill = minor), merge.

Done criteria: verbatim bodies diff-clean against source except attribution and mapped calls; no `CONTEXT.md` write path outside brainstorming; no new dependency; no HTML/CDN text in the plugin.

## Decisions needed

1. Per-task TDD reviewer stays **one** teammate (recommended) vs two-axis per task.
2. Drop the HTML report (recommended) vs port it as a markdown-to-Artifact step.
3. design-it-twice offered from brainstorming's Architectural path only (recommended) vs also Bounded.
