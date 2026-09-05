# Assessment: superteam agent roster (intentional models, named roles)

Brief (Cameron via lead-b, 2026-09-05): `model: inherit` everywhere is expensive. Design a small named roster, each agent's model chosen for the reasoning its task needs; fold `agents/ic.md` in; map every dispatch site; propose the skill rule "name the agent, never `general-purpose`, never inherit by default". Ground in prior art and cite what each entry inherits. Plan only, no build.

## Prior art mined

**Upstream superpowers 6.3.0** (`~/.claude/plugins/cache/claude-plugins-official/superpowers/6.3.0`): no `agents/` dir. Roles live only in prompt templates, all dispatched as `general-purpose`: `implementer-prompt.md`, `task-reviewer-prompt.md` (spec compliance + code quality in ONE seat), `re-review-prompt.md`, `requesting-code-review/code-reviewer.md`, `brainstorming/spec-document-reviewer-prompt.md`, `writing-plans/plan-document-reviewer-prompt.md`. Its "Model Selection" section is the strongest prior: least powerful model per role; mechanical = cheap, integration = standard, architecture/final review = most capable; **explicit model REQUIRED because an omitted model inherits the session's most expensive one**; "turn count beats token price" (mid-tier floor for reviewers and prose-brief implementers; cheapest tier only when the plan text contains the code). `dispatching-parallel-agents` shows `model: "sonnet"` per call. superteam already carries all of this; the roster makes it structural instead of a placeholder in every prompt.

**mattpocock 1.2.0** `agents/openai.yaml` files: Codex UI metadata only (`display_name`, `short_description`, `allow_implicit_invocation`). No roles, models, tools or effort anywhere. Role splits come from skill bodies: `code-review` runs Standards and Spec as two parallel `general-purpose` subagents that never share context, each with a fixed brief and a word cap ("under 400 words", "the sub-agent has no other access to it" → paste the baseline); `DESIGN-IT-TWICE` dispatches 3-4 design agents each under one constraint and compares; `improve-codebase-architecture` uses the built-in `Explore` subagent for the walk. Nothing to inherit on model choice.

**Claude Code agent frontmatter** (docs cache): `model` (`haiku|sonnet|opus|fable|inherit`), `effort` (`low..max`, overrides session), `tools` / `disallowedTools`, `isolation: worktree`, `maxTurns`, `skills` (preload), `background`, `color`. Plugin agents ignore `hooks`, `mcpServers`, `permissionMode`. A skill's `Agent` call can still override `model` per dispatch.

## Roster (6 agents, `agents/*.md`, invoked as `superteam:<name>`)

| Agent | Purpose | Model + why | Effort | Tools | Runs as | Inherits from | Never |
|---|---|---|---|---|---|---|---|
| **researcher** | Read-only investigation that returns a conclusion, not file dumps: codebase walks, spike probes, docs/API lookup, one design brief in a design-it-twice pass | `sonnet` — synthesis across files needs more than lookup; pure file-finding stays on the built-in `Explore` (haiku-class, already exists, reuse it) | medium | read-only: `disallowedTools: Edit, Write, NotebookEdit`; Bash allowed for `git log/show`, test runs | subagent, no isolation, parallel-safe | Matt: Explore walk + design-agent briefs (one constraint each); superteam brainstorming Spike path | Edit files, propose commits, spawn agents, write to CONTEXT.md |
| **implementer** | = today's `ic.md`, renamed. Owns one task's files in a worktree, TDD, commits, reports diff + Proposed terms | `sonnet` default — bounded implementation from a brief; lead overrides per Model Selection: `haiku` when the plan text contains the code (transcription + tests), `opus` for multi-file integration or a fix-loop escalation | medium | all | named subagent + `isolation: worktree` | upstream implementer-prompt + Model Selection; superteam ic.md 6-step body | Touch files outside the brief, edit CONTEXT.md/ADRs, spawn reviewers, merge |
| **reviewer** | Reads a diff or a document once and returns a verdict with file:line evidence. Seats: per-task (spec+quality, one seat), Standards axis, Spec axis, scoped re-review, spec-document review, plan-document review | `sonnet` default (mid-tier floor: "turn count beats price"); lead overrides to `opus` for the final whole-branch review and for Standards on risky diffs (concurrency, contracts, shared state); `haiku` never (misses subtle findings, costs re-rounds) | high | read-only as researcher; may run one focused test per named doubt | teammate (no isolation), parallel-safe — the two axes run side by side | upstream task-reviewer/re-review/code-reviewer/spec+plan doc reviewers; Matt two-axis split + "no other access, paste it" + word cap | Edit, re-run whole suites, rerank across axes, spawn a second opinion |
| **skeptic** | The veteran skeptic. Given a design, plan, candidate list or design-it-twice comparison, returns numbered objections: what is over-engineered, what pages someone at 3am, what was tried before and why it failed, what the deletion test says. Each item gets `kill / keep / shrink`; ends with the one thing he'd cut first | `opus` (or `fable` where available) — judgement is the whole job; a cheap model agrees with the design | high | read-only as researcher | subagent, sequential (one voice, after the approaches exist, before the spec is written) | New (Cameron). Doctrine sources already in superteam: brainstorming YAGNI, Speculative Generality + Middle Man smells (smell-baseline.md), deletion test (codebase-design), TDD "test only at confirmed seams" | Rewrite the design, soften a finding, block (the human decides), edit anything |
| **writer** | Prose deliverables: spec and plan drafts when the lead delegates them, README/docs tasks in a plan, skill text, ADR *drafts* for the human, reports. Follows elements-of-style, "your human partner" voice, exact values verbatim | `sonnet` — structured prose from a brief; `opus` only for skill text (behaviour-shaping content, per writing-skills) | medium | all, but the brief names the files | named subagent + `isolation: worktree` (same shape as implementer, different system prompt: no TDD, self-review checklist instead) | New. Prompt shape from implementer-prompt; checklist from brainstorming "Spec self-review" + writing-plans plan-review categories | Invent values not in the brief, write CONTEXT.md or ADRs (drafts go to the human), touch code |
| **integrator** | Mechanics after review: merge worktree branches into lane/trunk, resolve textual conflicts, run the full suite, `review-package`, remove worktrees + branches, bump every manifest version, ledger the merge | `sonnet` — conflicts need some judgement; sequential turns dominate cost, not tokens | low | all; runs in the lead's cwd (needs trunk) | subagent, no isolation, **one at a time** (mutates the shared checkout) | New. Steps from team-driven-development "5. Complete the task", finishing-a-development-branch, and this PM's merge flow (diff → merge --no-ff → remove worktree → delete branch → bump → tag task) | Push, rewrite history, resolve a *semantic* conflict silently (report it), edit skill/code content, skip a failing test |

Roles deliberately merged: task-reviewer + standards + spec + re-review + doc reviewers → one `reviewer` (same tools and rules, different prompt file); Explore stays built-in rather than a seventh agent; "fixer" for the fix loop = `implementer` resumed by name; "architect" = the lead in brainstorming, not an agent.

## reviewer vs skeptic (no overlap by construction)

| | reviewer | skeptic |
|---|---|---|
| When | post-build: a diff exists | pre-build: end of brainstorming, on writing-plans output, on a candidate list |
| Question | is this diff right? Standards and Spec, file:line | does this deserve to exist? what breaks at 3am, what would you delete, where is the hidden coupling |
| Input | diff + spec/plan/brief | spec, plan, approaches, design-it-twice comparison — never a diff |
| Output | Critical/Important/Minor with evidence; per-axis worst | numbered items each `kill / keep / shrink` + one line why; one closing "cut this first" |
| Model | sonnet, opus for final | opus/fable always |

A finding that belongs to the other seat is handed back, not answered: grumpy never comments on a diff's correctness; reviewer never asks whether the feature should exist (scope creep is a Spec finding against the spec, not a kill vote).

## Dispatch-site map (every current site → agent, model rule)

| Skill / site | Today | Proposed |
|---|---|---|
| team-driven-development §1 implementer (`implementer-prompt.md`, SKILL "Two kinds of IC") | `superteam:ic`, model placeholder | `superteam:implementer`; model line becomes "default sonnet; override per Model Selection" |
| team-driven-development §3 task review (`task-reviewer-prompt.md`), §4 re-review (`re-review-prompt.md`) | `general-purpose` teammate, model placeholder | `superteam:reviewer`, default model; final review seats → `opus` override |
| team-driven-development Final Review (two-axis) | two `general-purpose` via requesting-code-review | two `superteam:reviewer` (standards-reviewer.md, spec-reviewer.md), `model: opus` |
| team-driven-development §5 complete task, Finish (merge, worktree cleanup, workspace delete) | lead does it inline | `superteam:integrator`, one dispatch per merge |
| requesting-code-review §4 (standards + spec) | two `general-purpose` | two `superteam:reviewer` |
| brainstorming Spike "Investigate", Architectural "Explore project context" when it needs a walk | inline / unspecified | `superteam:researcher` (or built-in `Explore` for pure lookup) |
| brainstorming Architectural step 4→5 (after approaches, before Present design) | none | `superteam:skeptic` on the recommended approach — **new gate, offered not forced** (decision 2) |
| brainstorming spec-document-reviewer-prompt | `general-purpose` | `superteam:reviewer` |
| brainstorming Write design doc (Architectural) | lead writes inline | stays inline by default; `superteam:writer` when the lead delegates (decision 1) |
| writing-plans plan-document-reviewer-prompt | `general-purpose` | `superteam:reviewer` |
| writing-plans (before plan review, large plans) | none | `superteam:skeptic` on the task breakdown, optional |
| codebase-design "Finding deepening candidates" walk | built-in `Explore` | keep `Explore` for the walk; `superteam:researcher` when the friction questions need synthesis across modules |
| codebase-design DESIGN-IT-TWICE design agents | `general-purpose` ×3-4 | `superteam:researcher` ×3-4 (one constraint each); then `superteam:skeptic` on the comparison |
| dispatching-parallel-agents example + rules | `general-purpose`, `model: "sonnet"` | edit → `superteam:implementer`; investigate → `superteam:researcher`; drop inline model in the example (the agent carries it) |
| finishing-a-development-branch merge/cleanup steps | lead inline | `superteam:integrator` |
| using-superteam/references/* (other harnesses) | `general-purpose`/`generalist` mappings | add one row: `superteam:<role>` → the harness's generic agent + that role's prompt file; unchanged behaviour |

## Skill rule (added to team-driven-development "Two kinds of IC" and dispatching-parallel-agents; one line in using-superteam references)

1. **Name the agent.** Every `Agent` call in a superteam skill uses `subagent_type: "superteam:<role>"` from the roster. `general-purpose` appears only in the other-harness fallback line.
2. **The agent carries the model.** Each agent file sets `model` and `effort` for its role. A skill overrides `model` on the call only with a reason from Model Selection written next to it (complete-code task → haiku; final review, risky diff, fix-loop round 4-5 → opus). `inherit` is never written anywhere.
3. **Tools follow the role.** Read-only roles carry `disallowedTools`; the skill never widens them.
4. **One role per seat.** A reviewer does not fix; a researcher does not edit; an implementer does not merge.

## Files on build

- `agents/researcher.md`, `implementer.md` (rename of ic.md, `model: sonnet`), `reviewer.md`, `skeptic.md`, `writer.md`, `integrator.md`
- Prompt files re-pointed: implementer-prompt, task-reviewer-prompt, re-review-prompt, standards-reviewer, spec-reviewer, spec-document-reviewer-prompt, plan-document-reviewer-prompt, DESIGN-IT-TWICE (subagent_type lines and model placeholder text)
- SKILL.md edits: team-driven-development (Two kinds of IC, Model Selection wording, §5/Finish → integrator), dispatching-parallel-agents (example + rule), brainstorming (grumpy gate line, researcher line), writing-plans (grumpy optional line), codebase-design (researcher/grumpy lines), requesting-code-review §4, finishing-a-development-branch (integrator), using-superteam references
- README "What's Inside" agents list; manifests (agents array if `.claude-plugin/plugin.json` lists agents explicitly); tests: a static test that every `subagent_type:` in skills/ names `superteam:<role>` with a matching `agents/<role>.md`, and no agent file says `inherit`
- Bump 6.7.0 (new agents = minor)

## Backlog (not built)

- `icp-*` agent class (e.g. `icp-tradesman`, `icp-boomer`): a read-only persona agent that reacts as a target customer to give a synthetic opinion on copy, UX and offers; `sonnet`; dispatched on demand from brainstorming or a writer review. Needs the merge-roles written reason before it is added (Cameron via lead, 2026-09-05).

## Decisions needed

1. **writer** as its own agent (recommended: distinct system prompt is the value) vs fold into implementer with a "prose task" note.
2. **skeptic gate** in brainstorming: offered on the Architectural path (recommended) vs mandatory before every spec.
3. **Default models** as tabled (researcher/implementer/writer/integrator sonnet, reviewer sonnet with opus for final, grumpy opus) — confirm, or name `fable` for grumpy.
4. **integrator** as an agent (recommended: keeps lead context small, one seat mutates trunk) vs keep merge steps inline in the lead.
