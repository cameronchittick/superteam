# Claude Code Tool Notes

No `claude-code-tools.md` existed before this note; it is added here because
this directory already hosts the per-platform tool-name mappings the other
reference files use, and Claude Code's Task tools are conditional in a way
worth spelling out once rather than in every skill that touches the ledger.

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
regardless of model. `CLAUDE_CODE_TASK_LIST_ID` scopes the shared list to a
session for cross-session sharing. See superteam-driven-development's
"Ledger" section for which of the two ledgers (live task list vs.
plan-file) applies in a given session.

## Teammate vs. subagent launch rule

A named `Agent` call with no `isolation` launches an in-process teammate
when agent teams are enabled (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`);
the same call with `isolation: "worktree"` always launches a background
subagent instead. Teammates inherit the Task tools when the lead's session
has them; worktree subagents never receive them, regardless of the lead's
own tool set.
