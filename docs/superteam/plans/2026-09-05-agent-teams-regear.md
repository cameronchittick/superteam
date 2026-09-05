# Agent-Teams Re-gear Plan

Date: 2026-09-05. Status: awaiting Cameron's approval before Phase 2 builds.
Sources: code.claude.com/docs/en/agent-teams.md, sub-agents.md, worktrees.md (fetched 2026-09-05, Claude Code 2.1.261).

## Goal

Re-gear the six workflow skills so that on Claude Code they run as
"one PM session + IC teammates in worktrees + cross-session peers via
SendMessage". Other harnesses keep working: the team path is an additive Claude Code branch in each skill, not a replacement, and the existing platform reference files stay. Skill identifiers stay `superteam:<existing-name>`.

## Verified facts the design rests on

1. **Agent teams** need `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` (Cameron has it). One team per session, no nested teams, lead is fixed.
2. **What makes a teammate**: an `Agent` call with a `name`. A named call that also passes `isolation: "worktree"` on the call launches a *named subagent in a worktree*, not a teammate. A true teammate runs in the lead's working directory and must call `EnterWorktree` itself to isolate.
3. **Both kinds are addressable**: `SendMessage({to: name})` resumes a named subagent or messages a teammate. Teammates can message each other; named subagents can too.
4. **Worktrees**: created under `.claude/worktrees/<name>` on branch `worktree-<name>`, branched from the repo's default branch (`worktree.baseRef: "fresh"`), or from the lead's HEAD with `worktree.baseRef: "head"` in settings. Auto-removed if unchanged. Isolation blocks git commands that target the main checkout.
5. **Shared task list**: `TaskCreate/TaskList/TaskUpdate` exist only in sessions with the Task tools; agents without them coordinate by message. Tasks persist under `~/.claude/tasks/session-*/`.
6. **Teammate limits**: in-process teammates cannot run background subagents; `/resume` does not restore teammates. Hooks `TeammateIdle`, `TaskCreated`, `TaskCompleted` can gate quality (exit 2 = push back).
7. **Cross-session**: `ListAgents` + `SendMessage` reach other local sessions (lead-b, other PMs). Messages arrive marked as from another session, never as user approval.

## Decision for Cameron: what is an "IC"?

| | A. Named subagent, `isolation: worktree` on the call (recommended for implementers) | B. True teammate (recommended for reviewers/researchers) |
|---|---|---|
| Isolation | Automatic worktree, git guarded | Shares PM cwd; must `EnterWorktree` itself |
| Result | Completion notification with final report; PM merges the branch | Idle notification; edits land wherever it worked |
| Coordination | PM-driven; SendMessage to resume | Shared task list, peer messaging, self-claim |
| Cost/limits | Cheaper, can nest own subagents | Full session each; no background subagents |

Recommendation: **A for code-producing tasks, B for review and debate**. This is exactly the shape this PM session used for Phase 1 and it worked (two ICs, two worktrees, PM merged both). Option A also degrades gracefully when agent teams are off.

## Skill-by-skill mapping

1. **subagent-driven-development** (568 lines) → team-driven development. Keep the ledger, review loop, model selection and breaker as is; they are harness-neutral and tuned. Change: implementer dispatch = `Agent` with `name`, `isolation: "worktree"`, explicit `model`; the implementer commits on its worktree branch and reports; PM reviews `git diff <lane>..worktree-<name>`, runs the reviewer, then `git merge --no-ff` into the lane and `git worktree remove` + `git branch -d`. Reviewers dispatched as B (no worktree). Add "dependent tasks": IC's first step is `git merge <lane>` so it starts from merged prior work (works with the default `fresh` base). Keep the non-Claude-Code path as the fallback branch.
2. **dispatching-parallel-agents** (167) → teammates. Same pattern; the dispatch example becomes three named `Agent` calls in one response; add "when the fixes touch files, use `isolation: worktree` and merge afterwards"; verification step stays.
3. **executing-plans** (64) → the no-team path. Drop the "tell your partner about subagents" note; state plainly: this is for a single session or an IC executing one plan alone. Add the cross-session milestone report (`SendMessage` to the session that briefed you, three lines max).
4. **writing-plans** (171) → plan = tasks a PM hands to ICs. Each task gets a "Files owned" line (no two concurrent tasks share a file), a "Depends on" line, and a model tier hint. Execution handoff offers: team-driven (recommended) or executing-plans.
5. **finishing-a-development-branch** (225) → base branch is the repo trunk named by the plan/brief, never assumed `main`; Option 1 merges lane → trunk locally and pushes if a remote exists; keep the three-option menu because production shipping still waits for Cameron.
6. **using-git-worktrees** (167) → native only. Keep Step 0 detection and Step 2/3 setup + baseline. Replace Step 1 with: PM isolates ICs via `isolation: worktree` on the Agent call; a teammate or solo session uses `EnterWorktree`; mention `worktree.baseRef` and `.worktreeinclude`. Keep Step 1b for harnesses without a native worktree tool; Claude Code never reaches it.

Untouched: brainstorming, systematic-debugging, TDD, verification-before-completion, requesting/receiving-code-review, writing-skills, using-superteam (already trimmed).

## Tasks (one IC each, worktree-isolated, PM reviews and merges)

- T5 using-git-worktrees rewrite (smallest, do first; others reference it)
- T6 subagent-driven-development re-gear (largest; update its three prompt files)
- T7 dispatching-parallel-agents + executing-plans
- T8 writing-plans + finishing-a-development-branch
- T9 PM: tests in `tests/claude-code/` updated (worktree-native-preference, sdd tests), `claude plugin validate`, scratch-session load, merge lane → main.

Done criteria: every skill's examples use only tool names verified above; `tests/claude-code` passes; plugin reloads.

## Open questions

1. Keep the identifier `superteam:subagent-driven-development` or rename to `team-driven-development`? Brief says names stay; plan assumes keep.
2. Should the plugin ship an `agents/ic.md` subagent definition (tools, model, `isolation: worktree` in frontmatter) so the PM can spawn `subagent_type: "superteam:ic"`? Cheap, optional; plan assumes no until asked.
