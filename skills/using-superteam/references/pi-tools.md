# Pi Tool Mapping

Skills speak in actions ("dispatch a subagent", "create a todo", "read a file"). On Pi these resolve to the tools below.

| Action skills request | Pi equivalent |
| --- | --- |
| Dispatch a subagent (`Subagent (general-purpose):` template) | Use an installed subagent tool such as `subagent` from `pi-subagents` if available |
| `subagent_type: "superteam:<role>"` (implementer, writer, researcher, reviewer, skeptic, integrator) | The same `subagent` tool with the named `*-prompt.md` file filled in; researcher, reviewer and skeptic are read-only — keep that rule by instruction in the prompt, since the tool cannot restrict tools. The researcher never edits an existing file but may create exactly one findings file per task (`docs/superteam/research/<date>-<slug>.md`). |
| Task tracking ("create a todo", "mark complete") | Use an installed todo/task tool if available, otherwise track tasks in the plan or `TODO.md` |

## Subagents

Pi core does not ship a standard subagent tool. The `pi-subagents` package is a strong optional companion and provides a `subagent` tool with single-agent, chain, parallel, async, forked-context, and resume/status workflows. If no subagent tool is available, do not fabricate `Task` calls; execute sequentially in the current session or explain that the optional subagent capability is not installed.

## Task lists

Pi core does not ship a standard task-list tool. If a todo/task extension is installed, use its documented tool. Otherwise use Superteam plan files, checklists in Markdown, or a repo-local `TODO.md` for task tracking. Older Superteam docs may refer to `TodoWrite`; treat that as the task-tracking action above.
