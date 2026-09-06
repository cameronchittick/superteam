# Superteam

Superteam is a complete software development methodology for your coding agents, built on top of a set of composable skills and some initial instructions that make sure your agent uses them.

## Table of Contents

- [How it works](#how-it-works)
- [Getting Started](#installation)
  - [Claude Code](#claude-code)
  - [Antigravity](#antigravity)
  - [Codex App](#codex-app)
  - [Codex CLI](#codex-cli)
  - [Cursor](#cursor)
  - [Devin CLI](#devin-cli)
  - [Factory Droid](#factory-droid)
  - [Gemini CLI](#gemini-cli)
  - [GitHub Copilot CLI](#github-copilot-cli)
  - [Grok Build CLI](#grok-build-cli)
  - [Kimi Code](#kimi-code)
  - [OpenCode](#opencode)
  - [Pi](#pi)
  - [Hermes Agent](#hermes-agent)
- [The Basic Workflow](#the-basic-workflow)
- [Credit](#credit)
- [What's Inside](#whats-inside)
- [Philosophy](#philosophy)
- [Contributing](#contributing)
- [Updating](#updating)
- [License](#license)

## How it works

It starts from the moment you fire up your coding agent. As soon as it sees that you're building something, it *doesn't* just jump into trying to write code. Instead, it steps back and asks you what you're really trying to do. 

Once it's teased a spec out of the conversation, it shows it to you in chunks short enough to actually read and digest. 

After you've signed off on the design, your agent puts together an implementation plan that's clear enough for an enthusiastic junior engineer with poor taste, no judgement, no project context, and an aversion to testing to follow. It emphasizes true red/green TDD, YAGNI (You Aren't Gonna Need It), and DRY. 

Next up, once you say "go", it launches a *superteam-driven-development* process, having agents work through each engineering task, inspecting and reviewing their work, and continuing forward. It's not uncommon for your agent to work autonomously for a couple hours at a time without deviating from the plan you put together.

There's a bunch more to it, but that's the core of the system. And because the skills trigger automatically, you don't need to do anything special. Your coding agent just has Superteam.


## Installation

Installation differs by harness. If you use more than one, install Superteam separately for each one.

### Claude Code

Superteam is available via the [official Claude plugin marketplace](https://claude.com/plugins/superteam)

#### Official Marketplace

- Install the plugin from Anthropic's official marketplace:

  ```bash
  /plugin install superteam@claude-plugins-official
  ```

#### Superteam Marketplace

The Superteam marketplace provides Superteam and some other related plugins for Claude Code.

- Register the marketplace:

  ```bash
  /plugin marketplace add ~/Code/cameronchittick/superteam
  ```

- Install the plugin from this marketplace:

  ```bash
  /plugin install superteam@cameronchittick
  ```

#### Agent teams

Superteam's team-driven workflows need both env vars set — add them to your
shell profile:

```bash
# ~/.zshrc
export CLAUDE_CODE_ENABLE_TODO_TOOLS=1
export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
```

- Or ask Claude to run `superteam:setup-superteam`, which merges the same two vars into the `env` block of your `~/.claude/settings.json` and shows you the diff. A plugin cannot set them for you: a plugin's own `settings.json` supports only the `agent` and `subagentStatusLine` keys.

Also recommended, in your Claude Code settings:

```json
{
  "subagentPromptCacheTtl": "1h"
}
```

Keep a team to 3–5 role teammates, with 5–6 tasks per teammate — beyond
that, split into a second lane rather than growing one team. Without both
env vars (or on any other harness), Superteam falls back to the 6.10.0
worktree-subagent path automatically; no configuration is required to use
that path.

### Antigravity

Install Superteam as a plugin from this repository:

```bash
agy plugin install ~/Code/cameronchittick/superteam
```

Antigravity runs the plugin's session-start hook, so Superteam is active from
the first message. Reinstall with the same command to update.

### Codex App

Superteam is available via the [official Codex plugin marketplace](https://github.com/openai/plugins).

- In the Codex app, click on Plugins in the sidebar.
- You should see `Superteam` in the Coding section.
- Click the `+` next to Superteam and follow the prompts.

### Codex CLI

Superteam is available via the [official Codex plugin marketplace](https://github.com/openai/plugins).

- Open the plugin search interface:

  ```bash
  /plugins
  ```

- Search for Superteam:

  ```bash
  superteam
  ```

- Select `Install Plugin`.

### Cursor

- In Cursor Agent chat, install from marketplace:

  ```text
  /add-plugin superteam
  ```

- Or search for "superteam" in the plugin marketplace.

### Devin CLI

- Install the plugin from this repository:

  ```bash
  devin plugins install ~/Code/cameronchittick/superteam
  ```

- Update to the latest version with:

  ```bash
  devin plugins update superteam
  ```

### Factory Droid

- Register the marketplace:

  ```bash
  droid plugin marketplace add ~/Code/cameronchittick/superteam
  ```

- Install the plugin:

  ```bash
  droid plugin install superteam@superteam
  ```

### Gemini CLI

- Install the extension:

  ```bash
  gemini extensions install ~/Code/cameronchittick/superteam
  ```

- Update later:

  ```bash
  gemini extensions update superteam
  ```

### GitHub Copilot CLI

- Register the marketplace:

  ```bash
  copilot plugin marketplace add ~/Code/cameronchittick/superteam
  ```

- Install the plugin:

  ```bash
  copilot plugin install superteam@cameronchittick
  ```

### Grok Build CLI

Superteam is available via the [official Grok plugin marketplace](https://github.com/xai-org/plugin-marketplace).

- Install the plugin from xAI's official marketplace:

  ```bash
  grok plugin install superteam@xai-official --trust
  ```

- Or open the marketplace in the TUI, search for Superteam, and install it:

  ```text
  /marketplace
  ```

### Kimi Code

Superteam is available in Kimi Code's plugin marketplace.

- Open Kimi Code's plugin manager:

  ```text
  /plugins
  ```

- Go to `Marketplace` > `Superteam` and install it.

- Or install directly from this repository:

  ```text
  /plugins install ~/Code/cameronchittick/superteam
  ```

- Detailed docs: [docs/README.kimi.md](docs/README.kimi.md)

### OpenCode

OpenCode uses its own plugin install; install Superteam separately even if you
already use it in another harness.

- Tell OpenCode:

  ```
  Fetch and follow instructions from ~/Code/cameronchittick/superteam/.opencode/INSTALL.md
  ```

- Detailed docs: [docs/README.opencode.md](docs/README.opencode.md)

### Pi

Install Superteam as a Pi package from this repository:

```bash
pi install ~/Code/cameronchittick/superteam
```

For local development, run Pi with this checkout loaded as a temporary package:

```bash
pi -e /path/to/superteam
```

The Pi package loads the Superteam skills and a small extension that injects the `using-superteam` bootstrap at session startup and again after compaction. Pi has native skills, so no compatibility `Skill` tool is required. Subagent and task-list tools remain optional Pi companion packages.

### Hermes Agent

Install Superteam as a Hermes plugin from this repository:

```bash
hermes plugins install ~/Code/cameronchittick/superteam --enable
```

Restart any active Hermes sessions after installing. Note: Hermes has no
post-compaction hook, so a very long session that compacts over its first
turn loses the bootstrap — start a fresh session if skills stop triggering.

## The Basic Workflow

1. **brainstorming** - Activates before writing code. Refines rough ideas through questions, explores alternatives, presents design in sections for validation. Saves design document.

2. **using-git-worktrees** - Activates after design approval. Creates isolated workspace on new branch, runs project setup, verifies clean test baseline.

3. **writing-plans** - Activates with approved design. Breaks work into bite-sized tasks (2-5 minutes each). Every task has exact file paths, complete code, verification steps.

4. **superteam-driven-development** or **executing-plans** - Activates with plan. Dispatches one implementer IC per task, in its own worktree, with a two-axis per-task review, or executes in batches with human checkpoints.

   Per-task review is two reviewer seats running in parallel off the same diff: `Task N: review spec` judges the change against the plan task and the spec, `Task N: review standards` judges it against the repo's standards files and the smell baseline, citing file + rule. Merge waits on both, and the two axes are never reranked against each other.

   Every implement task's description carries a `Standards:` line — the repo's standards files (`CONTRIBUTING.md`, `CODING_STANDARDS.md`, `CLAUDE.md`, `AGENTS.md`, plus any the plan names), resolved once per plan. The implementer reads them first, and the standards reviewer judges against the same list.

5. **test-driven-development** - Activates during implementation. Enforces RED-GREEN-REFACTOR: write failing test, watch it fail, write minimal code, watch it pass, commit. Deletes code written before tests.

6. **requesting-code-review** - Activates between tasks. Reviews against plan, reports issues by severity. Critical issues block progress.

7. **finishing-a-development-branch** - Activates when tasks complete. Verifies tests, presents options (merge/PR/keep/discard), cleans up worktree.

**The agent checks for relevant skills before any task.** Mandatory workflows, not suggestions.

## Credit

Superteam is a fork of [obra/superpowers](https://github.com/obra/superpowers) by Jesse Vincent and Prime Radiant, used under the MIT license (see LICENSE). It is maintained by Cameron Chittick as a private plugin: trimmed to Claude Code agent teams while keeping other-harness support. The `domain-modeling` and `codebase-design` skills and the code-review smell baseline are ported from Matt Pocock's [skills](https://github.com/mattpocock/skills) (MIT), with their cross-skill plumbing mapped onto superteam's equivalents.

## What's Inside

### Skills Library

**Testing**
- **test-driven-development** - RED-GREEN-REFACTOR cycle (includes testing anti-patterns reference)

**Debugging**
- **systematic-debugging** - 4-phase root cause process (includes root-cause-tracing, defense-in-depth, condition-based-waiting techniques)
- **verification-before-completion** - Ensure it's actually fixed

**Collaboration** 
- **brainstorming** - Socratic design refinement
- **domain-modeling** - Build and sharpen the project's domain model: challenge terms, keep CONTEXT.md as the agreed glossary, record ADRs sparingly
- **codebase-design** - Deep-module vocabulary (module, interface, seam, adapter), deletion test, deepening candidates, design-it-twice
- **writing-plans** - Detailed implementation plans
- **executing-plans** - Batch execution with checkpoints
- **dispatching-parallel-agents** - Concurrent subagent workflows
- **requesting-code-review** - Pre-review checklist — two axes, Standards (repo standards + Fowler smell baseline) and Spec, reported side by side
- **receiving-code-review** - Responding to feedback
- **using-git-worktrees** - Parallel development branches
- **finishing-a-development-branch** - Merge/PR decision workflow
- **superteam-driven-development** (formerly subagent-driven-development) - Fast iteration with two-stage review (spec compliance, then code quality)

**Meta**
- **writing-skills** - Create new skills following best practices (includes testing methodology)
- **using-superteam** - Introduction to the skills system

### Agents

Named roles the skills dispatch as `superteam:<name>`; each carries its own model so nothing inherits the session's.

- **implementer** — owns one plan task's files in an isolated worktree, TDD, commits, reports a diff summary — opus
- **researcher** — investigation that returns a conclusion with file:line evidence, or one design-it-twice brief; never edits an existing file, and may create exactly one findings file per task (`docs/superteam/research/<date>-<slug>.md`) — sonnet
- **reviewer** — reads a diff or document once and returns a verdict by severity; the prompt file it is filled with sets the rubric — opus
- **skeptic** — pre-build veteran skeptic: numbered kill/keep/shrink verdicts on a spec, plan or approach list — opus
- **writer** — prose deliverables (spec/plan drafts, docs, skill text, ADR drafts) in an isolated worktree, self-review instead of TDD — opus
- **integrator** — merges a reviewed branch, runs the full suite, removes the worktree, bumps manifests when told — sonnet

The plugin's `worker_model` and `review_model` userConfig keys name the
intended knob for the three `opus` seats, but Claude Code does not substitute
`${user_config.*}` in agent frontmatter (verified 2.1.263), so the model is
set directly in `agents/*.md`.

A role's `skills:` frontmatter preloads those skills on a **subagent** spawn
only; a teammate spawn does not load them, so teammates invoke each with the
`Skill` tool (verified 2026-09-06).

### Agent-team hooks

Four hooks are bundled and wired into `hooks/hooks.json`, so they run
automatically on Claude Code — no `settings.json` changes needed. The three
task hooks gate only on a task subject matching `Task N: <title>` (the format
[superteam-driven-development](skills/superteam-driven-development/SKILL.md)'s
shared task list uses); every other task list — including a PM's own
coordination list — is untouched. `SUPERTEAM_SKIP_VERIFY_GATE=1` bypasses
all four.

- **`task-created-check`** (`TaskCreated`) — rejects a new task (exit 2,
  reason fed back) when its subject lacks a `[role]` tag from the agent
  roster, its step is not one of `implement`, `merge`, `fix <r>`,
  `review spec [r]` or `review standards [r]` (a bare `review` names no
  axis), or its description lacks a `Files owned:` line or a `Done:`
  line; also rejects when its `Files owned:` overlaps a pending or
  in-progress task on the same list that isn't in the same `Task N:`
  family and isn't named on its `Depends on:` line.
- **`teammate-idle-claim`** (`TeammateIdle`) — when a teammate goes idle,
  looks for a pending, unowned, unblocked task matching its role (read from
  the team config member's `agentType`, `superteam:<role>`, and falling back
  to `SUPERTEAM_ROLE_<NAME>`); if one exists, exits 2 with
  `claim "<subject>"` so the teammate claims it; otherwise exits 0. Never
  names another role's task.
- **`task-completed-verify`** (`TaskCompleted`) — refuses completion (exit
  2, fed back to the model) unless it finds verification evidence: a
  `Verified:` or `Evidence:` line in the task description, or a
  `Tests:`/`Verified:`/`Evidence:` line with a value in that task's report
  file (see
  [verification-before-completion](skills/verification-before-completion/SKILL.md#evidence-line)
  for the exact format).
- **`bash-guard`** (`PreToolUse`, matcher `Bash`) — denies four commands that
  destroy work nobody asked to destroy: `tmux kill-server`, `git checkout .`,
  `git reset --hard`, and `rm -rf` reaching outside the working directory.
  Everything else passes in silence, and it fails open. A forbidden command
  counts only in command position — at the start of a line or right after a
  separator — so quoting one in text (an `echo`, a `grep` pattern, a heredoc
  writing a report) is allowed. A backtick is not a separator here, which
  means backtick-quoted prose passes and a backtick command substitution
  passes with it. It reads the command
  as text rather than running it — `cd /tmp && rm -rf ./x` reads as a relative
  target and a symlink out of the worktree is not resolved — so it is a
  guardrail against the common destructive typo, not a sandbox.

A monitor ships too, in `monitors/monitors.json`:

- **`stuck-tasks`** — names any task left `in_progress` with no update for
  `SUPERTEAM_STUCK_MINUTES` (default 20) minutes, once per task until its
  file changes.

### Tests

`bin/superteam-test` runs the whole suite — hooks, manifests, skill and agent
checks — and reports anything whose prerequisite is missing (`timeout`, `yq`,
`dot`) as SKIP rather than FAIL. Run a single suite directly with
`bash tests/<area>/<file>.sh`.

## Philosophy

- **Test-Driven Development** - Write tests first, always
- **Systematic over ad-hoc** - Process over guessing
- **Complexity reduction** - Simplicity as primary goal
- **Evidence over claims** - Verify before declaring success


## Contributing

The general contribution process for Superteam is below. Keep in mind that we don't generally accept contributions of new skills and that any updates to skills must work across all of the coding agents we support.

1. Fork the repository
2. Switch to the 'dev' branch
3. Create a branch for your work
4. Follow the `writing-skills` skill for creating and testing new and modified skills
5. Submit a PR, being sure to fill in the pull request template.

Skill-behavior tests use the drill eval harness from [superteam-evals](https://github.com/prime-radiant-inc/superteam-evals/), cloned into `evals/` — see `evals/README.md` for setup. Plugin-infrastructure tests live at `tests/` and run via the relevant `run-*.sh` or `npm test`.

See `skills/writing-skills/SKILL.md` for the complete guide.

## Updating

Superteam updates are somewhat coding-agent dependent, but are often automatic.

## License

MIT License - see LICENSE file for details
