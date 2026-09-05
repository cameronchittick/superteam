# Domain-Modeling Port Plan

Date: 2026-09-05. Status: assessment, awaiting Cameron's go.
Source: mattpocock/mattpocock-skills 1.2.0, `skills/engineering/domain-modeling/` (SKILL.md 74 lines, CONTEXT-FORMAT.md 60, ADR-FORMAT.md 47, agents/openai.yaml 4). MIT, Copyright 2026 Matt Pocock.

## Assessment

**What the skill is.** An *active* discipline for a human-in-the-loop design conversation: challenge terms against `CONTEXT.md`, sharpen fuzzy words, stress-test with scenarios, cross-check code, write resolved terms into `CONTEXT.md` immediately, offer ADRs only when hard-to-reverse + surprising + real trade-off. It says itself that merely *reading* `CONTEXT.md` is "a one-line habit any skill can do", not this skill.

**How upstream hooks it.** Invoked from grilling / grill-with-docs / wayfinder / triage (all HITL interview skills) as "run a grilling session using /domain-modeling". Consumer skills (tdd, diagnosing-bugs, improve-codebase-architecture) carry a one-line "read CONTEXT.md if it exists" habit. That split — active skill in the conversation, read-habit in the workers — maps cleanly onto superteam.

**Fit with Cameron's four requirements.**
1. Verbatim copy: the three files port unchanged apart from frontmatter. Only edit: relative links stay (same dir), `agents/openai.yaml` dropped (Codex UI metadata; superteam's Codex manifest doesn't use per-skill yaml). No paraphrase.
2. Agreed language: the skill already forbids batching and treats the human as the authority ("which is it?"). The IC rule (read + use, propose only) is *new* text and goes in superteam's files, not in the ported skill.
3. File shape: `CONTEXT.md` / `CONTEXT-MAP.md` / `docs/adr/` with lazy creation are in CONTEXT-FORMAT.md and ADR-FORMAT.md verbatim; nothing to add.
4. Hooks: below.

## Hook recommendation

| Hook | Recommend | Why | Cost |
|---|---|---|---|
| **brainstorming** | **Yes, primary** | It is superteam's grilling analog and the only HITL design conversation. Architectural + Bounded paths, step "Explore project context": read `CONTEXT.md`/`CONTEXT-MAP.md`; step "Ask clarifying questions": run superteam:domain-modeling alongside (challenge/sharpen/scenarios, update CONTEXT.md inline as terms resolve). Spec-writing step: spec must use glossary terms; terms the spec needs that CONTEXT.md lacks are resolved *with the human* before the spec is written. Spike path: read-only. | ~6 lines |
| **writing-plans** | Yes, read-only | Global Constraints gains "use CONTEXT.md terms in task names, file names, tests; do not invent synonyms". No writing: the plan writer inherits the spec's language. | 2 lines |
| **team-driven-development + agents/ic.md** | Yes, propose-not-write | ic.md step: "If `CONTEXT.md` exists, read it and use its terms in code, tests, commit messages. Do not edit CONTEXT.md, CONTEXT-MAP.md or docs/adr. If the task needs a term that isn't there or contradicts it, put it under *Proposed terms* in your final report." TDD SKILL: the lead collects *Proposed terms* from IC reports into the ledger and surfaces them under "Rulings I made" / at finish — the human decides whether to run domain-modeling. Reviewer prompt: "flag names that contradict CONTEXT.md". | ~8 lines total |
| **using-superteam bootstrap** | **No** | Injection is exactly 60 lines now; one more line breaks the cap. The habit lives where the reading happens (brainstorming, ic.md, plans), which is also where upstream puts it. | 0 |
| **finishing-a-development-branch** | **No** (light option) | A drift check here is late: the branch is done and the human is choosing merge/PR. Drift is caught earlier by the reviewer flag and the IC *Proposed terms*. If wanted later: one line in Step 1 "if any IC reported Proposed terms, list them before the menu". | 0 (1 if opted) |

Also **systematic-debugging** and **test-driven-development**: upstream gives its tdd/diagnosing skills the read habit. Cheap (1 line each) and consistent; recommended as a follow-up, not this PR, to keep the diff reviewable.

## Tasks (after go)

- T12 (IC port) Copy the three files verbatim to `skills/domain-modeling/`; frontmatter unchanged except confirm `name: domain-modeling`; add `## Attribution` footer line "Ported from mattpocock/mattpocock-skills (MIT, © 2026 Matt Pocock)". Append Matt Pocock's MIT notice to LICENSE as a second section; add one credit line to README's Credit section; add `domain-modeling` to the README skill list and to the codex/kimi/devin keyword lists.
- T13 (IC hooks) brainstorming (~6 lines at the three points above), writing-plans Global Constraints (2 lines), agents/ic.md (one numbered step), team-driven-development (ledger + Finish + reviewer prompt lines), all with the exact propose-not-write wording from requirement 2.
- T14 (PM) validate, hook tests, fresh `claude -p` loads `superteam:domain-modeling`, bump 6.5.0 (new skill = minor), merge after go.

Done criteria: skill loads; `diff` of the three ported bodies against source shows only frontmatter/attribution changes; bootstrap injection still 60 lines; no file outside the list above touched.
