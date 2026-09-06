# Audit: Superteam workflow skills/agents vs. agent-teams, tools-reference, hooks, env-vars docs

Read in full: agent-teams.md, hooks.md (relevant sections), env-vars.md (relevant vars), tools-reference.md (full, incl. "Task tool availability" and "Agent tool behavior").

Mechanism key: (a) shared task list, (b) blockedBy deps, (c) self-claim, (d) teammate↔teammate SendMessage, (e) idle vs completion notification, (f) plan mode + auto-approval, (g) TaskCreated/TaskCompleted/TeammateIdle hooks, (h) subagent-definition-as-teammate semantics, (i) in-process vs split-pane, (j) no background subagents/no nested teams, (k) Task tool availability gating, (l) named Agent+isolation:worktree still a teammate.

---

## skills/superteam-driven-development/SKILL.md

| Mechanism | Verdict | Evidence |
|---|---|---|
| (a) shared task list | contradicts (by omission — see Contradictions) | `SKILL.md:232-240` builds its own ledger (`<workspace>/progress.md`, `Task <N>: complete` lines) with zero reference to `TaskCreate/TaskList/TaskUpdate`. |
| (b) blockedBy deps | ignores | No `blockedBy`/dependency API used anywhere; task ordering is inferred by the lead from the plan's prose "Depends on" field (not present in this file, see writing-plans). |
| (c) self-claim | contradicts by design | `SKILL.md:194-207` (Process diagram) and the whole Task Loop assume the **lead dispatches every task explicitly**; no teammate ever self-claims the next task. This is an intentional architecture choice, not an oversight — flagged as a Decision below. |
| (d) teammate↔teammate SendMessage | uses (partially) | `SKILL.md:127-128`: "A reviewer may `SendMessage` the implementer by name to ask what a change was for." One explicit non-lead-mediated message path. |
| (e) idle vs completion notification | uses, correctly | `SKILL.md:322-324`: "an IC's result arrives as a completion notification (subagent) or idle notification (teammate) — never poll for it." Matches `agent-teams.md:301-304` and `tools-reference.md:99` exactly. |
| (f) plan mode + auto-approval | n/a | Never invoked; ICs work from an inlined brief, not their own plan-mode pass. |
| (g) hooks | ignores | Zero mention of `TaskCreated`/`TaskCompleted`/`TeammateIdle` anywhere in the 733-line file, despite the file already enforcing quality gates (fix loop, breaker) that these hooks could back. |
| (h) subagent-def-as-teammate | uses (implicitly), partial | Roster agents (`agents/*.md`) are named subagent definitions dispatched via `subagent_type: "superteam:<role>"` — exactly the pattern `agent-teams.md:263-279` describes. But the skill never discusses the **body-append-vs-replace** distinction (in-process appends the agent file's body to the default prompt; split-pane replaces it) or that `skills:` fields (none set here) are ignored for teammates. |
| (i) in-process vs split-pane | ignores | No mention that Task-tool availability, and body handling, differ between the two display modes (`tools-reference.md:526`). Skill assumes one uniform teammate behavior. |
| (j) no background subagents/no nested teams | uses, aligned | `SKILL.md:369-373` (implementer "never dispatches subagents... not helpers, and never a reviewer") and reviewer/re-review templates repeat the "You Do Not Dispatch Subagents" rule — functionally matches `agent-teams.md:473-474`, though justified by roster architecture rather than citing the platform limitation. |
| (k) Task tool availability gating | ignores | No reference to `CLAUDE_CODE_ENABLE_TODO_TOOLS`, the Sonnet 5/Opus 4.8/Fable 5/Mythos 5 opt-out list (`tools-reference.md:515`), or `CLAUDE_CODE_TASK_LIST_ID`. The plan-file ledger is used unconditionally, even on models/sessions that do have the Task tools. This is the crux of task #2. |
| (l) named Agent+isolation:worktree as teammate | uses, correctly | `SKILL.md:113-116`: "Reviewer — a named agent with NO isolation... when agent teams are enabled it runs as a true teammate in your working directory, otherwise as a named subagent — the call is the same either way." Matches `agent-teams.md:227` precisely. Implementer/writer are never stated this way, but the same rule applies to them since `isolation` is orthogonal to team-vs-subagent status (`tools-reference.md:31` confirms `isolation: worktree` is a "pinned working directory" concept independent of Agent-tool teammate spawning) — SKILL.md never states this explicitly for implementer/writer, which is a **gap**, not a contradiction. |

---

## skills/superteam-driven-development/implementer-prompt.md

| Mechanism | Verdict |
|---|---|
| (a)(b)(c)(f)(g)(k) | n/a — this is a dispatch template, not policy; it inherits SKILL.md's choices |
| (d) | ignores — only says "ask questions now" / escalate to controller, never mentions messaging another IC |
| (e) | contradicts SKILL.md's nuance — `implementer-prompt.md:162-171` and the parallel line in `agents/implementer.md:60` unconditionally frame the failure mode as "reaches the lead as repeated idle notices," with no subagent/teammate branch. See Contradictions. |
| (h)/(i)/(l) | n/a at this layer |
| (j) | uses — "You Do Not Dispatch Subagents" section (`implementer-prompt.md:69-79`) restates the no-nested-teams rule for the IC's own scope |

## skills/superteam-driven-development/task-reviewer-prompt.md

| Mechanism | Verdict |
|---|---|
| (d) | n/a — template doesn't instruct the reviewer to message anyone (the SendMessage-implementer allowance lives only in SKILL.md prose, not in this template or in `agents/reviewer.md`) — **inconsistency**, see Contradictions |
| (e) | n/a — reviewer has no long-running command it would report on mid-turn in this template |
| (j) | uses — "You Do Not Dispatch Subagents" (`task-reviewer-prompt.md:56-63`) |
| others | n/a |

## skills/superteam-driven-development/re-review-prompt.md

Same shape as task-reviewer-prompt.md: (j) uses (`re-review-prompt.md:49-56`); all others n/a for a scoped review template.

---

## skills/dispatching-parallel-agents/SKILL.md

| Mechanism | Verdict | Evidence |
|---|---|---|
| (a) shared task list | n/a | Skill is about ad hoc parallel Agent dispatch outside any plan/lead ledger context; no task list of any kind is used, ledger or native. |
| (c) self-claim | n/a | Fixed roster of independent problems assigned up front, not claimed. |
| (d) SendMessage | uses | `SKILL.md:105`: "resume the agent by name with `SendMessage` instead of re-dispatching." Correct per `tools-reference.md:49` (SendMessage resumes a subagent by name) and matches teammate messaging too. |
| (e) idle vs completion | ignores | No distinction drawn between "Agent calls return, wait for them" language (`SKILL.md:98-99`, "When agents return") and the fact that under agent teams this becomes idle notifications, not a synchronous return. Written as if always synchronous/blocking, which is only true for non-team subagents. |
| (i) in-process vs split-pane | n/a | Not discussed; skill predates/ignores agent-teams entirely. |
| (j) nested teams | n/a | Not stated but not violated either — agents dispatched here are `superteam:implementer`/`superteam:researcher`, whose own agent files forbid sub-dispatch. |
| (l) named+worktree as teammate | ignores | `SKILL.md:71-75` dispatches named, worktree-isolated implementers exactly like SDD but never notes that with agent teams enabled these become teammates (with idle-notification semantics, not a blocking return) — the skill's mental model ("Multiple dispatch calls in one response = parallel execution... When agents return") reads as classic subagent-only semantics. |

---

## skills/writing-plans/SKILL.md

| Mechanism | Verdict | Evidence |
|---|---|---|
| (a) shared task list | ignores | Plan's "Depends on:" field (`SKILL.md:90, 141`) is free text for a human/lead to read, never wired to `TaskCreate`/`addBlockedBy`. |
| (b) blockedBy | ignores | Same — dependency info is prose, not a task-graph edge. This is the natural place `addBlockedBy` would slot in if SDD adopted the native task list. |
| (c)(d)(e)(f)(g)(h)(i)(j)(k)(l) | n/a | This skill only produces the planning document; it doesn't dispatch agents. |

---

## skills/executing-plans/SKILL.md

| Mechanism | Verdict | Evidence |
|---|---|---|
| (a) shared task list | contradicts by omission | `SKILL.md:23-31`: "Mark as in_progress... Mark as completed" — this is exactly `TaskUpdate` status-workflow language (`TaskUpdate` tool description: "Status progresses: pending → in_progress → completed") but the skill never names the tool; on a model where Task tools are absent by default (Sonnet 5, Opus 4.8, Fable 5, Mythos 5+) this instruction has nothing to act on unless the session opted in, and the skill doesn't say so. |
| (b)-(l) | n/a | Single-agent path explicitly out of scope for teams ("A lead with a team uses superteam:superteam-driven-development instead," `SKILL.md:14`); no dispatch, no teammates. |

---

## skills/finishing-a-development-branch/SKILL.md

| Mechanism | Verdict | Evidence |
|---|---|---|
| (l) named Agent as teammate | uses, correctly (implicit) | `SKILL.md:91-98` dispatches `superteam:integrator` with no `isolation`, matching the Reviewer/Integrator pattern elsewhere — same teammate-or-subagent duality applies and isn't restated, consistent with SKILL.md's convention of stating it once (in SDD) and reusing the pattern silently. |
| (g) hooks | n/a | Nothing here would naturally hook `TaskCompleted`; the test-verification gate (Step 1) is inline, not task-list-mediated. |
| others | n/a | Everything else in this skill is plain git mechanics, no team semantics. |

---

## skills/using-git-worktrees/SKILL.md

| Mechanism | Verdict | Evidence |
|---|---|---|
| (l) named Agent+isolation:worktree | uses, correctly | `SKILL.md:57`: "pass `isolation: 'worktree'` on the `Agent` tool call. Claude Code creates the worktree at `.claude/worktrees/<name>`... Git commands aimed at the main checkout are blocked inside it." Matches `tools-reference.md:31` (EnterWorktree entry) and `agent-teams.md` isolation-orthogonal-to-teammate reading. Correctly separates "isolating a teammate (you are PM/lead)" from "isolating yourself." |
| (i) in-process vs split-pane | n/a | Worktree mechanics are independent of display mode. |
| (j) | n/a | Not a dispatch skill. |
| others | n/a |

---

## skills/using-superteam/SKILL.md (+ references/)

| Mechanism | Verdict | Evidence |
|---|---|---|
| (a)-(l) | n/a | This is the meta bootstrap skill (skill-invocation discipline); it never touches agent-teams mechanics. `references/*.md` are per-harness tool-name mappings (Codex/Pi/Antigravity/Hermes) for platforms that predate/lack agent teams — correctly out of scope for this audit's mechanisms; not reviewed line-by-line since none of (a)-(l) apply to non-Claude-Code harnesses. |

---

## agents/implementer.md

| Mechanism | Verdict | Evidence |
|---|---|---|
| (d) SendMessage | uses, lead-only | `implementer.md:37-38`: "SendMessage the lead by name and wait for the answer" — never messages another IC directly (asymmetric with SKILL.md's reviewer→implementer allowance). |
| (e) idle vs completion | contradicts SKILL.md's own nuance | `implementer.md:60`: "an early 'waiting for tests' reply reaches the lead as repeated idle notices" — stated unconditionally. Idle notices are a **teammate**-only concept (`agent-teams.md:303`, `hooks.md:2592` TeammateIdle); when agent teams are disabled, this same Agent call is an ordinary subagent, which returns exactly once and has no idle-notice mechanism at all (`tools-reference.md:99`: subagent "returns a single text result... parent doesn't see intermediate... only that final result"). The rule is right for the teammate case and inapplicable/unverifiable for the subagent case, but the file doesn't branch on it the way `SKILL.md:322-324` does. |
| (j) no nested teams | uses | `implementer.md:35, 62-65`: "Do not spawn subagents or reviewers" / "Never:... spawn reviewers." |
| (h) subagent-def-as-teammate | uses (unaware) | Frontmatter `isolation: worktree`, `model: sonnet`, `effort: medium`, no `tools:`/`disallowedTools:` — under `agent-teams.md:275`, a teammate spawned from this definition would inherit every subagent tool plus `SendMessage` (+ Task tools if the session has them), which the body's "you do not spawn subagents" instruction constrains behaviorally rather than via the `tools` field. Consistent, but relies entirely on prose discipline rather than the `tools:` allowlist — worth noting since `disallowedTools` is used by researcher/reviewer/skeptic but not implementer/writer/integrator. |
| (k) | n/a — file doesn't address Task tool gating |
| (l) | n/a — isolation is set here, teammate-vs-subagent framing lives in SKILL.md only |

## agents/writer.md

Identical structure and identical finding to implementer.md for (d), (e) (`writer.md:64`, same unconditional "idle notices" phrasing), (j) (`writer.md:38, 66-69`), (h).

## agents/integrator.md

| Mechanism | Verdict | Evidence |
|---|---|---|
| (e) | contradicts SKILL.md's nuance, same pattern | `integrator.md:48`: same unconditional "idle notices" line. Integrator has **no** `isolation` field, so when agent teams are disabled it is unambiguously an ordinary subagent — making the "idle notices" phrasing here the least defensible of the three (no worktree isolation to even suggest team-only usage). |
| (d) | uses, lead-only | `integrator.md:40-41`. |
| (j) | n/a | Integrator doesn't do multi-step exploratory work that would tempt sub-dispatch; no explicit "never spawn" line, but none needed given its narrow merge-only scope. |
| (k)/(l) | n/a | No `isolation`; teammate-vs-subagent duality applies identically to reviewer per SKILL.md's stated rule, just never restated here. |

## agents/researcher.md

| Mechanism | Verdict | Evidence |
|---|---|---|
| (d) | uses, lead-only | `researcher.md:25-26`. |
| (e) | n/a | No long-running command pattern like implementer/writer/integrator; file doesn't make the idle-notice claim at all — internally consistent by omission. |
| (h) | uses | `disallowedTools: Edit, Write, NotebookEdit` (`researcher.md:6`) — this is the pattern `tools-reference.md:107-112` and `agent-teams.md:275` describe cleanly (disallowedTools removes the listed tools from the inherited set; SendMessage/Task tools still flow through since they're not in the exclusion list). |
| (j) | uses | `researcher.md:24`: "Do not spawn agents." |

## agents/reviewer.md

| Mechanism | Verdict | Evidence |
|---|---|---|
| (d) | contradicts SKILL.md | `reviewer.md:31-32` says only "SendMessage the lead by name" — no mention of the implementer-messaging allowance SKILL.md grants at `SKILL.md:127-128`. A reviewer following only its own agent file would not know it may contact the implementer. |
| (h) | uses | Same `disallowedTools` pattern as researcher. |
| (j) | uses | `reviewer.md:39`: "spawn a second opinion" listed under Never. |
| (e) | n/a | No long-running-command claim in this file. |

## agents/skeptic.md

| Mechanism | Verdict | Evidence |
|---|---|---|
| (d) | uses, lead-only | `skeptic.md:34-35`. |
| (h) | uses | `disallowedTools: Edit, Write, NotebookEdit` (`skeptic.md:6`). |
| (j) | uses | `skeptic.md:32, 47`. |
| others | n/a — skeptic never touches diffs/tasks/tests, so (e)/(k)/(l) don't arise |

---

## Contradictions that must change

1. **"Idle notices" stated unconditionally in agent files, but idle notifications are teammate-only.** `agents/implementer.md:60`, `agents/writer.md:64`, `agents/integrator.md:48` all assert that an early "waiting" reply "reaches the lead as repeated idle notices" with no branch on whether agent teams are enabled. Per `agent-teams.md:303` and `tools-reference.md:99`, a non-team subagent returns exactly one result and has no idle-notice channel — the claim as written is simply false when `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` is unset (the default). `SKILL.md:322-324` already gets this right ("completion notification (subagent) or idle notification (teammate)") — the three agent files should match that phrasing instead of asserting one universal mechanism.
2. **Reviewer→implementer SendMessage is documented in one place and contradicted by silence in two others.** `skills/superteam-driven-development/SKILL.md:127-128` grants reviewers permission to message the implementer directly; `agents/reviewer.md:31-32` and `skills/superteam-driven-development/task-reviewer-prompt.md` (no SendMessage guidance at all) don't carry that permission forward. A reviewer teammate spawned from `agents/reviewer.md` alone would not discover this allowance.
3. **The ledger's own bookkeeping vocabulary ("mark as in_progress," "mark as completed") echoes the native `TaskUpdate` status workflow verbatim** (`skills/executing-plans/SKILL.md:23-31` vs. `TaskUpdate` tool description) without ever naming the tool, on a codebase where the task list is frequently unavailable by default (Sonnet 5/Opus 4.8/Fable 5/Mythos 5, `tools-reference.md:515`). This isn't a factual contradiction in the docs but it is an internal contradiction of intent: the skill is written as if a task list obviously exists, then implements its own instead.

## Gaps worth filling additively (ranked)

1. **Task tool availability gating is never checked or mentioned anywhere in the ten files.** SDD's plan-file ledger is the right fallback for models that lack Task tools by default, but the skill should detect/state when the session *does* have them (`CLAUDE_CODE_ENABLE_TODO_TOOLS=1`, `--allowedTools TaskCreate`, non-listed models, background/cloud sessions per `tools-reference.md:524`) and use the native list as the primary ledger there, falling back to the plan-file only when Task tools are absent. This is task #2 on the shared list.
2. **No TaskCreated/TaskCompleted/TeammateIdle hook examples anywhere**, despite SDD already having exactly the quality-gate logic (`fix loop`, `breaker`, self-review checklist) these hooks are designed to enforce mechanically instead of by prose discipline alone. Task #4.
3. **blockedBy dependency graph unused.** `writing-plans`' "Depends on:" field is prose the lead reads by eye; wiring it to `TaskUpdate`'s `addBlockedBy`/`addBlocks` (when Task tools are present) would let Claude Code auto-unblock dependent tasks (`agent-teams.md:246`) instead of the lead tracking it manually.
4. **In-process vs. split-pane divergence is invisible to every skill.** Task tool availability, model effort inheritance timing (pre/post v2.1.186), and system-prompt body handling (append vs. replace) all differ by display mode (`agent-teams.md:165, 277`; `tools-reference.md:526`). None of the ten files acknowledge that a user running `teammateMode: "tmux"` gets materially different IC behavior than the (default) in-process mode.
5. **Self-claim is unused by design but never stated as a deliberate choice.** Worth one line in SDD's "Two kinds of IC" section explaining why the lead retains full dispatch control rather than letting ICs self-claim from a shared list — otherwise a future editor may "fix" this as an oversight.
6. **Plan mode for teammates (auto-approval) is never offered as an option**, e.g. for a risky task where the lead might want the implementer to plan first. Given SDD's "four things stop you" list already treats "a plan so broken every path forward is a guess" as a stop condition, offering plan-mode ICs for exploratory/high-risk tasks (with the lead's plan-mode auto-approval) is a natural, additive option — not a replacement for the brief-driven flow.
7. **`disallowedTools` inconsistency across the roster.** researcher/reviewer/skeptic declare `disallowedTools: Edit, Write, NotebookEdit`; implementer/writer/integrator declare neither `tools` nor `disallowedTools`, relying purely on prose ("never spawn subagents," "never edit outside the brief") to constrain a mutation-capable role. Since teammate spawning from a named definition applies the `tools`/`disallowedTools` fields mechanically (`agent-teams.md:275`), the write-capable roles get no tool-level backstop at all — worth a decision on whether that's acceptable given worktree isolation already limits blast radius.

## Decisions Cameron must make

1. **Should the SDD plan-file ledger be replaced, or dual-tracked, with the native shared task list when Task tools are present?** (Task #2.) The plan-file ledger survives compaction and works on every model; the native list gets automatic dependency unblocking, hook enforcement, and cross-session sharing via `CLAUDE_CODE_TASK_LIST_ID`. A hybrid (native list as source of truth when available, plan-file as the compaction-proof mirror always written) is possible but adds complexity — this is a real fork, not a bug fix.
2. **Should implementer/writer/reviewer ever self-claim from a shared list, or must the lead always explicitly dispatch?** Current design is 100% lead-directed by choice. Adopting self-claim would change the core "PM briefs each IC precisely" principle SKILL.md states as load-bearing (`SKILL.md:14`) — worth an explicit yes/no rather than a silent drift either way.
3. **Should TaskCompleted/TeammateIdle hooks become a required part of the SDD flow (auto-run tests before a task can be marked complete) or stay purely opt-in documentation?** (Task #4.) Making them required changes SDD from "lead enforces via review loop" to "harness enforces via hook," which shifts trust and failure modes (e.g., a hook that fails silently on a misconfigured test command could block completion the lead has no visibility into).
4. **Should the write-capable roster agents (implementer, writer, integrator) gain an explicit `tools`/`disallowedTools` allowlist**, now that we know the field is applied mechanically at teammate-spawn time, or is worktree isolation considered sufficient containment on its own?
5. **Should reviewer→implementer SendMessage be formalized in `agents/reviewer.md` and the task-reviewer template** (making it a first-class, documented capability) or removed from `SKILL.md:127-128` to keep all cross-IC communication lead-mediated, matching every other role's "SendMessage the lead only" rule?
