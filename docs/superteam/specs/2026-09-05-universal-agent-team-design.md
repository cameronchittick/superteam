# Universal agent-team system — design (superteam 7.0.0)

Date: 2026-09-05. Harness: Claude Code 2.1.263. Brief: Cameron via lead-b
(`project-lead/docs/superteam/plans/2026-09-05-universal-agent-team-system.md`).
Design approved by lead-b 22:07 with calls (a)–(d) below.

## Goal

Every superteam workflow that dispatches more than one agent runs as a
Claude Code agent team when the session has teams, and falls back to the
6.10.0 subagent path otherwise. The plan becomes a task graph on the
shared task list; role-typed teammates self-claim their own role's next
unblocked task; the lead creates, watches and steers, never implements.

## Verified facts the design rests on (2.1.263, 2026-09-05)

1. A subagent never receives the Task tools, whatever its allowlist says.
   Four probes: `general-purpose` from a Task-enabled session; fresh
   `claude -p` agent with no `tools`; fresh `-p` agent with
   `tools: Read, TaskList, TaskUpdate, TaskCreate, TaskGet` → only Read;
   `ToolSearch select:TaskList` → no match. Contradicts tools-reference
   "Task tool availability". Filed as a bug by lead-b; repro kept in the
   audit doc.
2. An in-process teammate (named `Agent` call, no `isolation` on the call)
   has TaskList/TaskUpdate/TaskCreate/TaskGet, SendMessage, Agent,
   EnterWorktree, ExitWorktree. Its `EnterWorktree` moves only itself to
   `.claude/worktrees/<name>` on branch `worktree-<name>`; the lead's cwd is
   unchanged.
3. Frontmatter `isolation: worktree` does not stop a teammate launch; only
   `isolation` on the call does (sub-agents.md, "isolation").
4. Frontmatter `effort` is honoured for subagents and ignored for teammates,
   which inherit the lead's effort and follow `/effort` (sub-agents.md
   frontmatter table; agent-teams.md "Specify teammates and models").
5. Hook payloads carry `task_id`, `task_subject`, `task_description`,
   `teammate_name`, `team_name`, `cwd`. TaskCreated: exit 2 or
   `{"decision":"block"}` deletes the task. TeammateIdle: exit 2 keeps the
   teammate working with stderr as its next prompt. TaskCompleted: exit 2
   refuses completion.

Consequence of 1+2: self-claim exists only for teammates. Implementers and
writers therefore run as teammates that isolate themselves with
`EnterWorktree`, not as worktree subagents. The subagent path stays as the
fallback.

## Modes

**Team mode** is on when all hold: `TaskCreate` is in the lead's tool list
(`CLAUDE_CODE_ENABLE_TODO_TOOLS=1` on the opt-in model families), agent
teams are on (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`), and the session is
interactive (`claude -p` never spawns teammates). The lead states the mode
once at Setup. Anything else is **fallback mode** = 6.10.0 behaviour:
worktree subagents, lead claims/completes tasks or keeps the plan-file
ledger, no teammates, no hooks fire on subagents. Other harnesses are
always fallback and their reference files are untouched.

## The task graph (SDD)

For plan task N the lead creates, in order:

| Subject | Role tag | blockedBy |
| --- | --- | --- |
| `Task N: implement [implementer]` (or `[writer]` for prose tasks) | implementer/writer | `Task M: merge` for each plan `Depends on: M` |
| `Task N: review [reviewer]` | reviewer | `Task N: implement` |
| `Task N: merge [integrator]` | integrator | `Task N: review` |

Fix rounds: `Task N: fix <r> [implementer]` blockedBy the review that raised
it, then `Task N: review <r> [reviewer]` blockedBy the fix; the merge task
gets `addBlockedBy` the last review. The lead creates fix/review pairs on
reading a review verdict; the merge task cannot be claimed until the last
review completes.

Description = the whole brief, no pointers, emitted by
`scripts/task-brief --taskcreate PLAN_FILE N [implement|review|merge]`:

```
Role: implementer
Plan: docs/superteam/plans/<plan>.md   Spec: <path or "none">
Lane: <lane branch>
Worktree: task-N-impl        (EnterWorktree name; branch worktree-task-N-impl)
Files owned: path/a, path/b  (exact list; the review and merge tasks repeat it)
Model: sonnet                (from the plan or the lead's model-selection rule)
Done: report at .superteam/sdd/<plan>/task-N-report.md with a `Tests:` line
## Task Brief
<verbatim plan task text>
## Global Constraints
<verbatim>
```

Review task descriptions add `Reviews: worktree-task-N-impl` and the
rubric pointer (`task-reviewer-prompt.md`); merge task descriptions add
`Merge: worktree-task-N-impl → <lane>`. `Files owned:` on review and merge
tasks is the same list; the TaskCreated overlap check exempts tasks in the
same `Task N:` family and upstream (blocking) tasks.

## Roles and self-claim

Teammates are spawned at Setup by role with predictable names:
`impl-1..k`, `writer-1`, `reviewer-1`, `integrator-1`. Pool default (call a):
1 implementer + 1 reviewer + 1 integrator for up to 6 plan tasks, one more
implementer per further 5 tasks, at most 5 teammates. A writer replaces an
implementer when the plan's tasks are prose.

Claim rule (identical text in every agent body): `TaskList` → pick the
first task that is pending, has no unresolved `blockedBy`, has no owner,
and whose subject carries your role tag → `TaskUpdate` owner=<your name>,
status=in_progress → do it → complete only with the Done evidence
written and appended to the task description as a `Verified:` line via
`TaskUpdate` (that line is what the TaskCompleted gate reads; a report file
inside a worktree is invisible to it). Never claim another role's task. An explicit assignment from the
lead (task already owned by you, or a message naming a task) wins over the
scan. If nothing matches, end the turn; the idle notification is the
report channel and the TeammateIdle hook re-prompts you when a task of your
role unblocks. File locking on the task dir makes two claims of one task
serialize; a teammate that reads back a different owner after its
TaskUpdate drops the task and rescans.

Per role:

- **implementer / writer** — first act after claiming: `EnterWorktree`
  with the description's `Worktree:` name; second: `git merge <lane>`.
  Work test-first, commit, write the report file relative to the worktree,
  `ExitWorktree` (keep), complete the task. Tools: Read, Edit, Write, Bash,
  Glob, Grep, Skill, EnterWorktree, ExitWorktree. maxTurns 60 (call c).
- **reviewer** — reads the worktree branch (`git diff <lane>..worktree-…`
  from the lead's checkout, or the worktree path), applies the rubric,
  writes findings into the review task's completion message and to
  `.superteam/sdd/<plan>/task-N-review.md`, completes. May
  `SendMessage` the implementer by name for clarification. maxTurns 30,
  `memory: project` (call b).
- **integrator** — claims `Task N: merge`, merges `worktree-task-N-impl`
  into the lane from the lead's checkout, runs the suite, removes worktree
  and branch, completes with the merge sha. maxTurns 20.
- **researcher / skeptic** — team modes below; researcher maxTurns 30,
  skeptic maxTurns 30, `memory: project` on skeptic (call b).

`effort: high` stays on reviewer and skeptic for the subagent path; the
body says once that as a teammate you run at the lead's effort.

Rules in every body: no `background` runs, no spawning teammates or nested
teams (foreground subagents only), never hand-edit `~/.claude/tasks/**` or
`~/.claude/teams/**`, never end a turn with a command running, report in
the final answer (subagent) or before going idle (teammate).

Split-pane mode replaces the system prompt with the agent body, so bodies
are self-sufficient: role, claim rule, worktree steps, report format, and
the guard list live in the body, not in a dispatch template. Dispatch
prompts carry only name, model and the pointer "your tasks are on the
shared list".

## Lead loop

Setup: lane branch, workspace, `task-brief --taskcreate` per plan task into
`TaskCreate` (hook validates each), `addBlockedBy` per `Depends on:`,
pre-approve common operations (call d: write the allow-list to
`.claude/settings.local.json`; ask the lead before touching committed
`.claude/settings.json`; never `--dangerously-skip-permissions`, never ask
a peer to run a denied command), spawn the role pool, state the mode.

Monitor: on each idle notification read it as the report; `TaskList`;
nudge a teammate by name whose task shows in_progress without progress;
reassign a stuck task by resetting it to pending and messaging; create
fix/review pairs on verdicts; rulings still go to `progress.md`. The lead
never claims an implement/review/merge task itself.

Restart: `TaskList`; reset in_progress tasks whose owner is not in
`~/.claude/teams/<team>/config.json` members to pending; re-spawn one
teammate per role that has open tasks.

Teardown (finishing-a-development-branch): when a role has no pending
tasks, `SendMessage` `shutdown_request` to each idle teammate of that role;
when all merges are done, merge lane → trunk, then shut down the rest.

## Hooks (all bundled, all gated on subject `^Task [0-9]+:`)

- **TaskCreated** `hooks/task-created-check`: reject (exit 2 with reason)
  when the subject lacks a `[role]` tag from the roster, or the description
  lacks a `Files owned:` line or a `Done:` line; reject when `Files owned:`
  overlaps any pending/in_progress task on the same list that is not in the
  same `Task N:` family and not upstream of it. Task dir =
  `~/.claude/tasks/${CLAUDE_CODE_TASK_LIST_ID:-$team_name}` (override
  `SUPERTEAM_TASKS_DIR` for tests). Fail-open on unparseable input.
- **TeammateIdle** `hooks/teammate-idle-claim`: read the idle teammate's
  role from its name prefix (`impl-`, `writer-`, `reviewer-`,
  `integrator-`, `researcher-`, `skeptic-`) or from `SUPERTEAM_ROLE_<NAME>`;
  if a pending, unowned, unblocked task with that role tag exists, exit 2
  with `claim "<subject>"`; else exit 0. Never names another role's task.
- **TaskCompleted** `hooks/task-completed-verify`: unchanged.

`SUPERTEAM_SKIP_VERIFY_GATE=1` bypasses all three. Tests: crafted JSON
payloads and a fake tasks dir for each hook, plus the fallback assertion
that nothing fires for non-`Task N:` subjects.

## Team modes in other skills

- **requesting-code-review** — two axes as two reviewer teammates
  (`review-spec`, `review-standards`) plus optional `lens-<name>`
  reviewers; the lead concatenates findings in reviewer order, no
  reranking. Fallback: two subagents as today.
- **systematic-debugging** — 3–5 `hyp-N` researcher teammates, one
  hypothesis each, told to disprove the others via SendMessage; lead
  collects survivors. Fallback: sequential researcher subagents.
- **brainstorming** — the skeptic offer may spawn `skeptic-1` as a live
  teammate for the session. Fallback: skeptic subagent.
- **dispatching-parallel-agents** — one pool of one role, one task per
  unit, self-claim. Fallback: today's subagents.

## Enable, detect, document

- **using-superteam** gains a Step 0 decision table (subagent / teammate /
  team of 3–5 / cross-session peer PM, with a cost row) and the detect line
  ("do I have TaskCreate? am I interactive? are teams on?"). File stays
  exactly 63 lines: Step 0 replaces lines of equal count in the Rule and
  Skill Priority sections.
- **README** requires both env vars, recommends
  `"subagentPromptCacheTtl": "1h"`, team size 3–5, 5–6 tasks per teammate,
  and documents the three hooks.
- **references/claude-code-tools.md** documents team config
  (`~/.claude/teams/<team>/config.json`, `members`), mailboxes, task dir,
  never hand-edit, peer discovery via config.json, model precedence (spawn
  prompt > definition > `CLAUDE_CODE_SUBAGENT_MODEL` > lead), teammateMode
  and the split-pane prompt replacement, and the subagent Task-tools bug.
- **Audit doc** `docs/superteam/plans/2026-09-05-agent-team-audit.md`
  rewritten: every feature from the ten sources with `source: <url>#<section>`,
  used-or-why-not, plus the bug repro and the effort finding.

## Dogfood

This spec's own plan runs as the graph above on list `superteam-pm` with
role teammates; the PM reports claim latency, lag between completion and
next claim, and any double-claim, in the final report.

## Out of scope

Other-harness team support; MCP; `permissionMode` in frontmatter (not a
plugin-agent field); changing the verify gate's evidence rule.
