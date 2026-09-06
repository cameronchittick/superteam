# Audit: agent-team features vs. superteam 7.0.0

Date: 2026-09-06. Harness: Claude Code 2.1.263. Superteam: 7.0.0 (per
`docs/superteam/specs/2026-09-05-universal-agent-team-design.md` and
`docs/superteam/plans/2026-09-05-universal-agent-team-system.md`). Sources
fetched 2026-09-06 05:21 UTC with `curl -fsSL <url> -o .superteam/src/<name>.md`
into this worktree's gitignored scratch dir; every fetch succeeded and every
file had at least one heading (Step 1 of the task brief). "Used where"
below reflects the state of `lane/7.0.0` at fetch time — the tasks this
plan is landing (implementer/reviewer/hook work not yet merged) are called
out explicitly where relevant.

---

## agent-teams.md

| Feature | Cite | Used where / why not |
|---|---|---|
| Two display modes, in-process (default) vs. split-pane | `source: https://code.claude.com/docs/en/agent-teams.md#choose-a-display-mode` | Not configured by superteam; `references/claude-code-tools.md` (Task 6, this plan) documents both modes' behavioral differences for skill authors, but no skill sets `teammateMode` itself — left to the operator. |
| Model precedence for teammates (spawn prompt > definition `model` > `CLAUDE_CODE_SUBAGENT_MODEL` > lead) | `source: https://code.claude.com/docs/en/agent-teams.md#specify-teammates-and-models` | Documented in `references/claude-code-tools.md` "Model precedence" (Task 6); agent roster files (`agents/*.md`) each set an explicit `model`, so they hit tier 2 rather than falling through to the lead. |
| Team config / mailboxes / task list under `~/.claude/teams/` and `~/.claude/tasks/` | `source: https://code.claude.com/docs/en/agent-teams.md#architecture` | Documented in `references/claude-code-tools.md` "Team files" (Task 6): never hand-edit, discover peers via `config.json`. `skills/superteam-driven-development/SKILL.md` uses the shared task list as its live ledger when `TaskCreate` is present. |
| Assign and claim tasks (self-claim from a shared list) | `source: https://code.claude.com/docs/en/agent-teams.md#assign-and-claim-tasks` | `skills/superteam-driven-development/SKILL.md`: reviewer and other in-process teammates self-claim via `TaskList`/`TaskUpdate`; worktree subagents cannot (see Findings, bug). `skills/dispatching-parallel-agents/SKILL.md` "Team mode" section (Task 5, this plan) also self-claims one pool of one role. |
| Shut down teammates (`shutdown_request`) | `source: https://code.claude.com/docs/en/agent-teams.md#shut-down-teammates` | `skills/finishing-a-development-branch/SKILL.md` "Team teardown" (Task 5, this plan): sends `{"type":"shutdown_request","reason":"role pool empty"}` to each idle teammate of an empty role. |
| Enforce quality gates with hooks | `source: https://code.claude.com/docs/en/agent-teams.md#enforce-quality-gates-with-hooks` | `hooks/task-completed-verify` (bundled, wired in `hooks/hooks.json`) plus `task-created-check` and `teammate-idle-claim` (Task 1, landing on this lane) implement exactly this pattern. |
| Use case: parallel code review / competing hypotheses | `source: https://code.claude.com/docs/en/agent-teams.md#use-case-examples`, `source: https://code.claude.com/docs/en/agent-teams.md#investigate-with-competing-hypotheses` | `skills/requesting-code-review/SKILL.md` "Team mode" (`review-spec`/`review-standards`/`lens-<name>`) and `skills/systematic-debugging/SKILL.md` "Team mode" (`hyp-N` researchers), both Task 5 of this plan, are direct implementations of these two documented use cases. |

## sub-agents.md

| Feature | Cite | Used where / why not |
|---|---|---|
| Supported frontmatter (`tools`, `disallowedTools`, `model`, `effort`, `isolation`, ...) | `source: https://code.claude.com/docs/en/sub-agents.md#supported-frontmatter-fields` | Every `agents/*.md` roster file sets `model`; `researcher`/`reviewer`/`skeptic` also set `disallowedTools: Edit, Write, NotebookEdit`; `implementer`/`writer` set `isolation: worktree`; none currently set `effort` (left to inherit). |
| Choose a model (per-subagent order) | `source: https://code.claude.com/docs/en/sub-agents.md#choose-a-model` | `references/claude-code-tools.md` "Model precedence" (Task 6) restates this order for teammates specifically. |
| Run subagents in foreground or background | `source: https://code.claude.com/docs/en/sub-agents.md#run-subagents-in-foreground-or-background` | Not used — superteam always runs ICs in the foreground of the lead's turn; no skill dispatches a background subagent. |
| Subagent output scanning | `source: https://code.claude.com/docs/en/sub-agents.md#subagent-output-scanning` | Not used/mentioned by any skill; superteam relies on the returned report text alone, not on the platform's automatic scan. |
| Fork the current conversation | `source: https://code.claude.com/docs/en/sub-agents.md#fork-the-current-conversation` | Not used by superteam — `superteam:*` agents are always non-fork, task-scoped dispatches; forking would carry the lead's whole context, which contradicts "precisely crafted context" in `skills/requesting-code-review/SKILL.md` and `skills/dispatching-parallel-agents/SKILL.md`. |

## plugins-reference.md

| Feature | Cite | Used where / why not |
|---|---|---|
| Skills component | `source: https://code.claude.com/docs/en/plugins-reference.md#skills` | `skills/*/SKILL.md` — superteam's entire library. |
| Agents component | `source: https://code.claude.com/docs/en/plugins-reference.md#agents` | `agents/*.md` — the roster (`implementer`, `writer`, `reviewer`, `integrator`, `researcher`, `skeptic`). |
| Hooks component | `source: https://code.claude.com/docs/en/plugins-reference.md#hooks` | `hooks/hooks.json` wires `SessionStart` and `TaskCompleted`; `task-created-check`/`teammate-idle-claim` land with Task 1 of this plan. |
| Plugin manifest schema | `source: https://code.claude.com/docs/en/plugins-reference.md#plugin-manifest-schema`, `source: https://code.claude.com/docs/en/plugins-reference.md#complete-schema` | `.claude-plugin/plugin.json` sets `name`, `description`, `version` (currently `6.10.0` on this branch — the lead bumps it to `7.0.0` at Finish), `author`, `license`, `keywords`. Nine manifests total are bumped at Finish per the plan's "Finish (lead)" step. |

## tools-reference.md

| Feature | Cite | Used where / why not |
|---|---|---|
| Agent tool behavior (single result vs. teammate messages) | `source: https://code.claude.com/docs/en/tools-reference.md#agent-tool-behavior` | `skills/superteam-driven-development/SKILL.md`: "an IC's result arrives as a completion notification (subagent) or idle notification (teammate) — never poll for it," directly reflecting this doc's "returns a single text result" vs. "reports back through team messages" split. |
| Task tool availability gating | `source: https://code.claude.com/docs/en/tools-reference.md#task-tool-availability` | `skills/superteam-driven-development/SKILL.md` Setup branches on whether `TaskCreate` is in the lead's tool list before choosing the live-ledger vs. plan-file path; `skills/using-superteam/SKILL.md` "Step 0" (Task 6) states the same gate for every skill that dispatches more than one agent. |

## hooks.md

| Feature | Cite | Used where / why not |
|---|---|---|
| `TaskCreated` event | `source: https://code.claude.com/docs/en/hooks.md#taskcreated` | `hooks/task-created-check` (Task 1, landing on this lane): rejects a task missing a `[role]` tag, `Files owned:`, or `Done:` line, or one whose `Files owned:` overlaps another in-flight task. |
| `TaskCompleted` event | `source: https://code.claude.com/docs/en/hooks.md#taskcompleted` | `hooks/task-completed-verify`, already bundled and wired in `hooks/hooks.json`: refuses completion without a `Verified:`/`Evidence:`/`Tests:` line. |
| `TeammateIdle` event | `source: https://code.claude.com/docs/en/hooks.md#teammateidle` | `hooks/teammate-idle-claim` (Task 1, landing on this lane): on idle, claims a pending unblocked task matching the teammate's role, or exits 0. |

## env-vars.md

| Feature | Cite | Used where / why not |
|---|---|---|
| `CLAUDE_CODE_ENABLE_TODO_TOOLS` (opts newer model families into Task tools) | `source: https://code.claude.com/docs/en/env-vars.md#variables` | Required by `README.md` "Agent teams" section (Task 6) alongside the export block; gates `skills/using-superteam/SKILL.md` Step 0's team-mode detect line. |
| `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` (enables agent teams) | `source: https://code.claude.com/docs/en/env-vars.md#variables` | Same as above — both env vars are required together, per the same README section and Step 0 detect line. |
| `CLAUDE_CODE_TASK_LIST_ID` (share a task list across sessions) | `source: https://code.claude.com/docs/en/env-vars.md#variables` | Documented in `references/claude-code-tools.md` "Availability gate" (Task 6), fixed to say it names the on-disk task directory (verified 2.1.263) rather than the earlier, inaccurate pilot note. Not itself set by any skill — an operator/cross-session concern. |

## settings-reference.md

| Feature | Cite | Used where / why not |
|---|---|---|
| `subagentPromptCacheTtl` | `source: https://code.claude.com/docs/en/settings-reference.md#subagentpromptcachettl` | Recommended at `"1h"` in `README.md` "Agent teams" (Task 6), so repeated per-task dispatches reuse the cached prompt prefix. |
| `teammateMode` | `source: https://code.claude.com/docs/en/settings-reference.md#teammatemode` | Documented (not set) in `references/claude-code-tools.md` "teammateMode" (Task 6): behavioral differences between `in-process` and `tmux` that skill authors and the lead need to know, especially that a split-pane teammate's environment doesn't inherit from the lead process. |
| `permissions.allow` | `source: https://code.claude.com/docs/en/settings-reference.md#permissionsallow` | The Lead loop's Setup step (per the design spec) writes a pre-approved command allow-list to `.claude/settings.local.json` here rather than to the committed `.claude/settings.json`, so a team's routine commands don't stall on approval prompts. |

## cross-session-messaging.md

| Feature | Cite | Used where / why not |
|---|---|---|
| Message another session | `source: https://code.claude.com/docs/en/cross-session-messaging.md#message-another-session` | Not used inside a single agent team — teammates message each other via the in-team mailbox (`agent-teams.md#architecture`), a different mechanism. Cross-session messaging is called out only as the "cross-session peer PM" tier in `skills/using-superteam/SKILL.md` Step 0 (Task 6) — for a second repo or a second lead, not for team-internal coordination. |
| See which sessions Claude can reach | `source: https://code.claude.com/docs/en/cross-session-messaging.md#see-which-sessions-claude-can-reach` | Not used — no superteam skill currently coordinates across separate Claude Code sessions/repos; this is future scope if the cross-session-peer tier from Step 0 gets built out. |
| Restrict cross-session messaging | `source: https://code.claude.com/docs/en/cross-session-messaging.md#restrict-cross-session-messaging` | Not used — no skill sets messaging restrictions; out of scope for a single-repo plugin. |

## worktrees.md

| Feature | Cite | Used where / why not |
|---|---|---|
| How Claude Code enforces isolation (file edits, cwd, git redirects, command shape) | `source: https://code.claude.com/docs/en/worktrees.md#how-claude-code-enforces-isolation` | `skills/using-git-worktrees/SKILL.md` and every worktree-scoped IC prompt in `skills/superteam-driven-development/implementer-prompt.md` rely on this enforcement directly; this audit hit the "command shape" check itself mid-task (a compound `bash -c` with `&&` was refused and had to be split into separate commands). |
| Isolate subagents with worktrees | `source: https://code.claude.com/docs/en/worktrees.md#isolate-subagents-with-worktrees` | `agents/implementer.md` and `agents/writer.md` set `isolation: worktree`; `skills/dispatching-parallel-agents/SKILL.md` dispatches with `isolation: "worktree"` explicitly for any agent that edits files. |
| Clean up worktrees | `source: https://code.claude.com/docs/en/worktrees.md#clean-up-worktrees` | `skills/finishing-a-development-branch/SKILL.md` Step 6 ("Cleanup Workspace") implements this, including the harness-auto-remove case and the refused-removal escalation path. |

## interactive-mode.md

| Feature | Cite | Used where / why not |
|---|---|---|
| Task list (native `/tasks` list backing `TaskCreate`/`TaskList`/`TaskUpdate`/`TaskGet`) | `source: https://code.claude.com/docs/en/interactive-mode.md#task-list` | `skills/superteam-driven-development/SKILL.md` uses this as the live ledger (its "Ledger" section) whenever `TaskCreate` is in the lead's tool list; `skills/executing-plans/SKILL.md`'s "mark as in_progress / mark as completed" language echoes this same tool's status vocabulary without naming it (see Findings). |

---

## Findings

### 1. Subagent Task-tools bug (2.1.263)

A subagent never receives the Task tools, whatever its `tools:` allowlist
says. Repro: an agent file with

```yaml
tools: Read, TaskList, TaskUpdate, TaskCreate, TaskGet
```

dispatched as a plain `superteam:implementer`-style worktree subagent
(`isolation: worktree`, no teammate `name` recognized as a live teammate)
under a fresh `claude -p` invocation in a git repo with
`CLAUDE_CODE_ENABLE_TODO_TOOLS=1 CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`
set — the observed tool list at runtime is `Read` only; `ToolSearch
select:TaskList` inside that subagent returns no match. This contradicts
`source: https://code.claude.com/docs/en/tools-reference.md#agent-tool-behavior`,
which describes tool resolution purely in terms of `tools`/`disallowedTools`
with no carve-out for the Task tools. Consequence, already reflected in
`skills/superteam-driven-development/SKILL.md`: self-claim only works for
in-process teammates; worktree subagents are always claimed and completed
by the lead on their behalf.

### 2. Effort inheritance differs between subagents and teammates

`source: https://code.claude.com/docs/en/sub-agents.md#supported-frontmatter-fields`
documents `effort` as an honoured per-subagent override ("Effort level when
this subagent is active. Overrides the session effort level. Default:
inherits from session"). `source:
https://code.claude.com/docs/en/agent-teams.md#specify-teammates-and-models`
states the opposite for the same field's owner: "Teammates inherit the
lead's effort level" and later follow `/effort` for the rest of the
session — a teammate's own definition-level `effort` is not honoured the
way a subagent's is. No `agents/*.md` file currently sets `effort`, so this
divergence is latent rather than triggered today, but it means adding
`effort` to, say, `agents/skeptic.md` (opus, deliberately higher-effort)
would do nothing once that agent runs as a teammate instead of a subagent.

### 3. EnterWorktree pins only the caller in split-pane mode, not in-process

An in-process teammate shares the lead session's process working
directory: when it calls `EnterWorktree`, the lead's own cwd (and every
other in-process teammate's) moves too — observed directly in a dogfood
run where three implementers dispatched as in-process teammates each
called `EnterWorktree` and all three sets of edits landed in whichever
worktree the last call created. A split-pane teammate (`teammateMode:
"tmux"`) is its own OS process, so its `EnterWorktree` pins only itself;
the lead's cwd is unaffected. Neither `source:
https://code.claude.com/docs/en/worktrees.md#how-claude-code-enforces-isolation`
nor `source: https://code.claude.com/docs/en/agent-teams.md#architecture`
states this in-process-vs-split-pane distinction explicitly — it is
documented here as an internally-verified gap, which is why
`references/claude-code-tools.md` (Task 6, this plan) calls it out under
"teammateMode" and why the design in
`docs/superteam/specs/2026-09-05-universal-agent-team-design.md` treats
worktree-isolating ICs as teammates that isolate *themselves*, never as
worktree subagents, whenever self-claim is required.

---

## Dogfood findings (2026-09-05, 2.1.263)

- `TaskCompleted` fires not only when a task is explicitly marked completed
  via `TaskUpdate`, but also when an agent-team teammate finishes its turn
  while still holding an in-progress task
  (`source: https://code.claude.com/docs/en/hooks.md#taskcompleted`). A gate
  hook that `exit 2`s in that second case re-prompts the same teammate in a
  loop — observed for roughly 30 rounds before the fix. Shipped fix: a
  once-per-state marker in the hook plus a "set the task back to pending and
  end the turn idle" protocol for a genuinely blocked teammate, instead of
  retrying the same refused completion.
- A split-pane teammate spawned with an explicit `tools:` allowlist gets only
  the tools that list names — no `ToolSearch`, no Task tools, no
  `SendMessage` unless the allowlist says so — while a `disallowedTools`
  agent keeps everything else in its pool
  (`source: https://code.claude.com/docs/en/sub-agents.md#available-tools`).
  7.0.0's allowlisted agents (`agents/*.md` with `tools:` set) now name the
  team tools explicitly so a split-pane teammate isn't silently cut off from
  them.
- Haiku cannot run in auto mode
  (`source: https://code.claude.com/docs/en/permission-modes.md#eliminate-prompts-with-auto-mode`):
  a haiku teammate prompts on every command instead, and that prompt lands in
  the lead's pane. Never spawn a haiku teammate under this design.
- A teammate's permission prompt appears only in the lead session's pane, and
  only a human can answer it there; a teammate stopped mid-command leaves its
  prompt standing until dismissed, stalling the lead
  (`source: https://code.claude.com/docs/en/agent-teams.md#permissions`). The
  lead loop must check its own pane for these, not assume a teammate resolves
  its own prompts.
- `source: observed` — a split-pane teammate reads the repo's
  `.claude/settings.local.json` allow list like any Claude Code process, but
  a compound command (`a && b`) does not match a bare `Bash(a)` rule, and the
  tmux pane's `PATH` is the bare system `PATH` — no `timeout`/`gtimeout` —
  so a test suite that shells out to either fails in a teammate pane even
  though it passes for the lead or in a plain worktree subagent.
- `source: observed` — `SendMessage` from a teammate to the lead succeeds
  ("sent to inbox") but is not surfaced to the lead mid-turn; a busy lead
  only sees it once its own turn ends, so the lead loop must end turns often
  or read task descriptions directly for verdicts rather than assuming a
  message will interrupt it.
- `source: observed` — in-process teammates share the session's process
  working directory, so one teammate's `EnterWorktree` moves the lead and
  every other in-process teammate's cwd too; a split-pane teammate is its own
  OS process, so its `EnterWorktree` pins only itself. (Already covered as
  Finding 3 above; repeated here because it is also a dogfood-run
  observation, not only a spec-review conclusion.)
- `source: observed` — the 6.10.0 completion gate looked up
  `task-<task_id>-report.md` by the task-list ID and truncated task
  descriptions at an escaped quote inside `json_field`; 7.0.0's gate instead
  takes `N` from the task's subject (`Task N: ...`) and fixes the
  `json_field` parser so an escaped quote in the description no longer cuts
  it short.

---

## Anchor check

```
$ fail=0
$ grep -o 'source: https://code.claude.com/docs/en/[a-z-]*\.md#[a-z0-9-]*' docs/superteam/plans/2026-09-05-agent-team-audit.md | sort -u | while read -r _ url; do
    f=".superteam/src/$(basename "${url%%#*}")"; a="${url##*#}"
    if grep -E '^#+ ' "$f" | sed -E 's/^#+ //; s/[^A-Za-z0-9 -]//g' | tr 'A-Z ' 'a-z-' | grep -qx "$a"; then continue; fi
    if grep -q "id=\"$a\"" "$f"; then continue; fi
    echo "MISSING $url"; fail=1
  done
$ echo "anchor check done"
anchor check done
```

`permission-modes.md` sets some anchors as an explicit `<h2 id="...">` rather
than a plain `#`/`##` line (e.g. `#eliminate-prompts-with-auto-mode`, whose
visible heading text is "Eliminate *permission* prompts with auto mode" —
the id itself omits "permission"), so the loop above falls back to matching
a literal `id="<anchor>"` attribute when the heading-text transform misses.

Actual run produced no `MISSING` lines, over 37 unique citations.

Tests: anchor check — 0 MISSING of 37 citations.
