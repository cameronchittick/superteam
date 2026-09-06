# Claude Code Tool Notes

Claude Code's Task tools are conditional; this note spells the gate out once
so the ledger-touching skills can point here.

## Step 0 decision table

| Need | Use | Cost |
| --- | --- | --- |
| One answer | subagent | 1 context |
| A worker that stays and reports | teammate | 1 context + mailbox |
| 3+ tasks or hypotheses | team of 3–5 role teammates | N contexts on one shared list |
| Another repo (or a second lead) | cross-session peer PM | separate session |

## Task tools (TaskCreate, TaskGet, TaskList, TaskUpdate)

| Tool | Purpose |
| --- | --- |
| `TaskCreate` | Create a task on the shared task list |
| `TaskGet` | Read one task's full detail |
| `TaskList` | List all tasks with status |
| `TaskUpdate` | Change status, dependencies (`addBlockedBy`), or details |

**Availability gate:** on Opus 4.8, Sonnet 5, Fable 5, Mythos 5, and later
versions of those families, Claude Code leaves these four tools (and
`TodoWrite`) out unless you opt in with `CLAUDE_CODE_ENABLE_TODO_TOOLS=1`
(or name one in `--allowedTools`/`--tools`). Every other model gets them by
default. Background sessions and Claude Code on the web get them
regardless of model. `CLAUDE_CODE_TASK_LIST_ID` names the on-disk task
directory shared across sessions (verified 2.1.263). See
superteam-driven-development's "Ledger" section for which of the two
ledgers (live task list vs. plan-file) applies in a given session.

## Teammate vs. subagent launch rule

A named `Agent` call with no `isolation` launches an in-process teammate
when agent teams are enabled (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`);
the same call with `isolation: "worktree"` always launches a background
subagent instead. Teammates inherit the Task tools when the lead's session
has them; worktree subagents never receive them, regardless of the lead's
own tool set.

## Team files

`~/.claude/teams/<team>/config.json` holds `members`; each teammate has its
own mailbox; the task dir is `~/.claude/tasks/<list>/`. Never hand-edit any
of these — a task or a member changes state only through the tools
(`TaskUpdate`, spawning/shutdown). Teammates discover their peers by
reading `config.json` and may message across roles, not just within their
own.

## Model precedence

`model` in the spawn call > `model` in the agent definition's frontmatter >
`CLAUDE_CODE_SUBAGENT_MODEL` > the lead's own model.

## teammateMode

`auto | in-process | tmux`. In split-pane (`tmux`) mode the agent's body
replaces its system prompt, so the body must be self-sufficient. A
split-pane teammate is its own OS process: it gets its environment from the
tmux session, not from the lead process, so `CLAUDE_CODE_TASK_LIST_ID` must
be set on the tmux session (or in settings `env`) or the teammate claims
against the wrong list. Its Task tools arrive deferred and load via
`ToolSearch`; `Glob` and `Grep` are absent. Its permission prompts surface
in the lead's pane, so pre-approve routine commands in
`.claude/settings.local.json`. In-process teammates instead share the lead
session's cwd, so one teammate's `EnterWorktree` moves the lead and every
other in-process teammate too.

## Effort

Frontmatter `effort` is honoured for subagents. Teammates ignore it and
inherit the lead's effort, following `/effort` changes for the rest of the
session.

## Known bug

On 2.1.263, a subagent never receives the Task tools, whatever its
allowlist says. Repro: an agent spawned with `tools: Read, TaskList` gets
only `Read`. Filed as a bug; this is why implementers and writers run as
teammates that isolate themselves with `EnterWorktree`, not as worktree
subagents, when self-claim matters.
