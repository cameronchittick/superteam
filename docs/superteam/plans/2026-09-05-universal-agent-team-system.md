# Universal Agent-Team System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superteam:superteam-driven-development (recommended) or superteam:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship superteam 7.0.0: every multi-agent workflow runs as a Claude Code agent team with a task graph and role-scoped self-claim, and falls back to 6.10.0 behaviour when teams are unavailable.

**Architecture:** Three bash hooks gate the shared task list (`TaskCreated` shape check, `TeammateIdle` role-aware claim nudge, `TaskCompleted` verify gate). `task-brief --taskcreate` turns a plan task into three `TaskCreate` bodies (implement/review/merge). Agent bodies are self-sufficient and carry the claim rule. Skills describe team mode and fallback side by side.

**Tech Stack:** bash (BSD-compatible sed/awk, no jq), markdown skills, Claude Code plugin manifests, existing `tests/**/*.sh` harness.

**Spec:** `docs/superteam/specs/2026-09-05-universal-agent-team-design.md`

## Global Constraints

- Plugin stays zero-dependency: hooks and scripts use only bash, sed, awk, grep, find; `python3` only inside tests.
- `skills/using-superteam/SKILL.md`: no tuned content (Rule, Skill Priority, Red Flags rows, User Instructions) is removed or reworded; Step 0 is added as a compact block of at most 4 lines. Line count ceiling: 67 (63 + Step 0), pending the human partner's ruling on the 63-line pin; if the ruling is "63 exact", the lead decides which lines pay for it, never the writer.
- Skill invocation prefix is `superteam:`; "your human partner" voice stays; never "the user".
- Agent frontmatter carries an explicit `model` (never `inherit`); `effort`, `maxTurns`, `memory`, `isolation` per the spec's "Roles and self-claim".
- Other harnesses keep the non-team path: no file under `skills/using-superteam/references/{codex,pi,antigravity,hermes}-tools.md`, `.codex-plugin/`, `.kimi-plugin/`, `.devin-plugin/`, `.hermes-plugin/`, `.cursor-plugin/`, `gemini-extension.json` changes in this plan except the 7.0.0 bump the lead does at Finish.
- Hooks fail open on unparseable input and exit 0 for any subject not matching `^Task [0-9]+:`; `SUPERTEAM_SKIP_VERIFY_GATE=1` bypasses every hook.
- Role tags are exactly: `[implementer]`, `[writer]`, `[reviewer]`, `[integrator]`, `[researcher]`, `[skeptic]`. A teammate's role is its `agentType` in the team config (`superteam:<role>`); names are free but predictable (`impl-1`, `reviewer-1`, `review-spec`, `hyp-3`).
- Every new bash test assertion goes through the file's `assert_exit`/`assert_stderr` helpers; test files run under `set -euo pipefail`, so never write a bare `out="$(hook)"` that can exit non-zero.
- Version is bumped to 7.0.0 in all nine manifests by the lead at Finish, not by any task.
- Every task's report at `.superteam/sdd/2026-09-05-universal-agent-team-system/task-N-report.md` (relative to the worktree) ends with a `Tests:` line naming the command run and its pass count; the same line is appended to the task description as `Verified: …` via `TaskUpdate` before completion.
- Use the terms in `CONTEXT.md` for task names, identifiers, file names and tests; do not coin synonyms. (No `CONTEXT.md` exists in this repo; the spec's terms — team mode, fallback mode, task graph, role tag, self-claim, Files owned — are the vocabulary.)

---

## File structure

| File | Responsibility | Task |
| --- | --- | --- |
| `hooks/task-created-check` | TaskCreated shape + overlap gate | 1 |
| `hooks/teammate-idle-claim` | TeammateIdle role-aware nudge | 1 |
| `hooks/hooks.json` | wire the two new hooks | 1 |
| `tests/hooks/test-team-hooks.sh` | tests for all three hooks + fallback | 1 |
| `skills/superteam-driven-development/scripts/task-brief` | `--taskcreate` emitter | 2 |
| `tests/claude-code/test-dispatch-template.sh` | tests for `--taskcreate` | 2 |
| `agents/*.md` (6) + `tests/claude-code/test-agent-roster.sh` | self-sufficient bodies, claim rule, frontmatter | 3 |
| `skills/superteam-driven-development/{SKILL.md,implementer-prompt.md,task-reviewer-prompt.md,re-review-prompt.md}` + `tests/claude-code/test-superteam-driven-development.sh` | task graph process | 4 |
| `skills/{requesting-code-review,systematic-debugging,brainstorming,dispatching-parallel-agents,finishing-a-development-branch}/SKILL.md` | team modes + teardown | 5 |
| `skills/using-superteam/SKILL.md`, `skills/using-superteam/references/claude-code-tools.md`, `README.md`, `hooks/session-start`, `tests/hooks/test-session-start.sh` | Step 0, enable/detect, docs | 6 |
| `docs/superteam/plans/2026-09-05-agent-team-audit.md` | primary-source audit | 7 |

---

### Task 1: Hooks — TaskCreated check and TeammateIdle claim

**Files owned:** `hooks/task-created-check`, `hooks/teammate-idle-claim`, `hooks/task-completed-verify`, `hooks/hooks.json`, `tests/hooks/test-team-hooks.sh`
**Depends on:** none
**Model tier:** standard

**Files:**
- Create: `hooks/task-created-check`
- Create: `hooks/teammate-idle-claim`
- Modify: `hooks/hooks.json` (add `TaskCreated` and `TeammateIdle` entries beside `TaskCompleted`)
- Modify: `hooks/task-completed-verify` (report lookup: take N from the subject's `Task N:` first, falling back to the digits of `task_id` — list ids and plan numbers differ once review/merge tasks exist)
- Test: `tests/hooks/test-team-hooks.sh` (extend; keep the 11 existing assertions)

**Interfaces:**
- Consumes: payload JSON on stdin with `task_id`, `task_subject`, `task_description`, `teammate_name`, `team_name`, `cwd` (hooks.md "TaskCreated", "TeammateIdle"). Task files at `${SUPERTEAM_TASKS_DIR:-$HOME/.claude/tasks/${CLAUDE_CODE_TASK_LIST_ID:-$team_name}}/*.json` with fields `id`, `subject`, `description`, `status`, `owner`, `blockedBy` (array of ids). Team config at `${SUPERTEAM_TEAMS_DIR:-$HOME/.claude/teams}/<team_name>/config.json` whose `members` array has objects with `name` and `agentType` (e.g. `"agentType": "superteam:reviewer"`) — verified on 2.1.263 team configs.
- Produces: `hooks/task-created-check` exit 2 + stderr reason to reject; `hooks/teammate-idle-claim` exit 2 + stderr `claim "<subject>"` to re-prompt; both `--help` print 5 lines. Role for the idle hook comes from the team config member's `agentType` (strip the `superteam:` prefix), else `SUPERTEAM_ROLE_<NAME>` (name upper-cased, `-`→`_`); no name-prefix parsing — teammate names are free (`review-spec`, `hyp-3`, `impl-1`). `hooks/run-hook.cmd <name>` dispatch is unchanged (it runs `hooks/<name>`).

Copy `json_field` and `json_unescape` from `hooks/task-completed-verify` verbatim into each new script (no shared lib — three files that must each run standalone under `run-hook.cmd`).

- [ ] **Step 1: Write the failing tests for task-created-check**

Append to `tests/hooks/test-team-hooks.sh` before the `hooks.json wiring` block:

```bash
CREATED_HOOK="$REPO_ROOT/hooks/task-created-check"
IDLE_HOOK="$REPO_ROOT/hooks/teammate-idle-claim"
tasks_dir="$TEST_ROOT/tasks"
mkdir -p "$tasks_dir"
# task 1: implement, owns hooks/a; task 2: review of task 1 (same family); task 3: merge (blockedBy 2)
cat > "$tasks_dir/1.json" <<'EOF'
{"id":"1","subject":"Task 1: implement [implementer]","description":"Files owned: hooks/a, hooks/b\nDone: report with Tests: line","status":"pending","owner":"","blockedBy":[]}
EOF
cat > "$tasks_dir/2.json" <<'EOF'
{"id":"2","subject":"Task 1: review [reviewer]","description":"Files owned: hooks/a, hooks/b\nDone: verdict","status":"pending","owner":"","blockedBy":["1"]}
EOF
cat > "$tasks_dir/3.json" <<'EOF'
{"id":"3","subject":"Task 3: implement [implementer]","description":"Files owned: skills/x\nDone: report","status":"completed","owner":"impl-1","blockedBy":[]}
EOF

echo "Team hooks: task-created-check"

good='{"task_id":"9","task_subject":"Task 2: implement [implementer]","task_description":"Files owned: skills/y\nDone: report with Tests: line"}'
assert_exit "well-formed Task N task is accepted" 0 "$good" SUPERTEAM_TASKS_DIR="$tasks_dir" -- "$CREATED_HOOK"
assert_exit "missing role tag is rejected" 2 '{"task_id":"9","task_subject":"Task 2: implement","task_description":"Files owned: skills/y\nDone: x"}' SUPERTEAM_TASKS_DIR="$tasks_dir" -- "$CREATED_HOOK"
assert_exit "unknown role tag is rejected" 2 '{"task_id":"9","task_subject":"Task 2: implement [wizard]","task_description":"Files owned: skills/y\nDone: x"}' SUPERTEAM_TASKS_DIR="$tasks_dir" -- "$CREATED_HOOK"
assert_exit "missing Files owned is rejected" 2 '{"task_id":"9","task_subject":"Task 2: implement [implementer]","task_description":"Done: x"}' SUPERTEAM_TASKS_DIR="$tasks_dir" -- "$CREATED_HOOK"
assert_exit "missing Done line is rejected" 2 '{"task_id":"9","task_subject":"Task 2: implement [implementer]","task_description":"Files owned: skills/y"}' SUPERTEAM_TASKS_DIR="$tasks_dir" -- "$CREATED_HOOK"
assert_exit "Files owned overlap with open task of another family is rejected" 2 '{"task_id":"9","task_subject":"Task 2: implement [implementer]","task_description":"Files owned: hooks/a\nDone: x"}' SUPERTEAM_TASKS_DIR="$tasks_dir" -- "$CREATED_HOOK"
assert_exit "Files owned overlap within the same Task N family is allowed" 0 '{"task_id":"9","task_subject":"Task 1: merge [integrator]","task_description":"Files owned: hooks/a, hooks/b\nDone: merge sha"}' SUPERTEAM_TASKS_DIR="$tasks_dir" -- "$CREATED_HOOK"
assert_exit "Files owned overlap with a completed task is allowed" 0 '{"task_id":"9","task_subject":"Task 4: implement [implementer]","task_description":"Files owned: skills/x\nDone: x"}' SUPERTEAM_TASKS_DIR="$tasks_dir" -- "$CREATED_HOOK"
assert_exit "non-Task-N subject is never gated" 0 '{"task_id":"9","task_subject":"Track the launch","task_description":""}' SUPERTEAM_TASKS_DIR="$tasks_dir" -- "$CREATED_HOOK"
assert_exit "SUPERTEAM_SKIP_VERIFY_GATE=1 bypasses task-created-check" 0 '{"task_id":"9","task_subject":"Task 2: implement","task_description":""}' SUPERTEAM_SKIP_VERIFY_GATE=1 -- "$CREATED_HOOK"
assert_exit "malformed JSON exits 0" 0 'nope {{' -- "$CREATED_HOOK"
```

- [ ] **Step 2: Run the test file; expect the new assertions to FAIL (hook missing)**

Run: `bash tests/hooks/test-team-hooks.sh`
Expected: `STATUS: FAILED` with the eleven new `[FAIL]` lines (command not found → exit 127).

- [ ] **Step 3: Write `hooks/task-created-check`**

```bash
#!/usr/bin/env bash
# TaskCreated hook for superteam. Gated on task_subject ^Task [0-9]+: —
# every other task is accepted untouched. Rejects (exit 2) a Task N task
# whose subject lacks a roster role tag, whose description lacks a
# "Files owned:" or "Done:" line, or whose Files owned overlap an open
# (pending/in_progress) task on the same list outside its own Task N family
# and not upstream of it. Task dir: SUPERTEAM_TASKS_DIR, else
# ~/.claude/tasks/${CLAUDE_CODE_TASK_LIST_ID:-team_name}. Fails open.
usage() {
    cat <<'EOF'
Usage: task-created-check
TaskCreated hook: rejects (exit 2) a "Task N:" task without a [role] tag,
a "Files owned:" line and a "Done:" line, or whose Files owned overlap an
open task outside its Task N family. Reads the TaskCreated JSON payload from stdin.
Set SUPERTEAM_SKIP_VERIFY_GATE=1 to bypass this gate.
EOF
}
[ "${1:-}" = "--help" ] && { usage; exit 0; }
[ "${SUPERTEAM_SKIP_VERIFY_GATE:-}" = "1" ] && exit 0
input="$(cat 2>/dev/null || true)"
json_field() { printf '%s' "$1" | tr '\n' ' ' | sed -n 's/.*"'"$2"'"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1; }
json_unescape() { printf '%s' "$1" | sed -e 's/\\n/\
/g' -e 's/\\"/"/g' -e 's/\\\\/\\/g'; }
subject="$(json_unescape "$(json_field "$input" "task_subject")")"
printf '%s' "$subject" | grep -qE '^Task [0-9]+:' || exit 0
desc="$(json_unescape "$(json_field "$input" "task_description")")"
family="$(printf '%s' "$subject" | sed -n 's/^\(Task [0-9]*\):.*/\1/p')"
if ! printf '%s' "$subject" | grep -qE '\[(implementer|writer|reviewer|integrator|researcher|skeptic)\]$'; then
    echo "Task subject must end with a role tag: [implementer] [writer] [reviewer] [integrator] [researcher] [skeptic]" >&2; exit 2
fi
owned="$(printf '%s\n' "$desc" | sed -n 's/^Files owned:[[:space:]]*//p' | head -1)"
[ -n "$owned" ] || { echo "Task description needs a 'Files owned: <paths>' line" >&2; exit 2; }
printf '%s\n' "$desc" | grep -qE '^Done:[[:space:]]*[^[:space:]]' || { echo "Task description needs a 'Done: <evidence>' line" >&2; exit 2; }
team="$(json_field "$input" "team_name")"
dir="${SUPERTEAM_TASKS_DIR:-$HOME/.claude/tasks/${CLAUDE_CODE_TASK_LIST_ID:-$team}}"
[ -d "$dir" ] || exit 0
for f in "$dir"/*.json; do
    [ -f "$f" ] || continue
    other="$(cat "$f" | tr '\n' ' ')"
    status="$(json_field "$other" "status")"
    case "$status" in pending|in_progress) ;; *) continue ;; esac
    osubj="$(json_unescape "$(json_field "$other" "subject")")"
    ofam="$(printf '%s' "$osubj" | sed -n 's/^\(Task [0-9]*\):.*/\1/p')"
    [ -n "$ofam" ] && [ "$ofam" = "$family" ] && continue
    oowned="$(json_unescape "$(json_field "$other" "description")" | sed -n 's/^Files owned:[[:space:]]*//p' | head -1)"
    set -f  # no globbing: a Files owned entry like agents/*.md is a literal
    for p in $(printf '%s' "$owned" | tr ',' ' '); do
        for q in $(printf '%s' "$oowned" | tr ',' ' '); do
            if [ "$p" = "$q" ]; then
                echo "Files owned overlap: '$p' is already owned by open task '$osubj' ($(basename "$f" .json)). Split the files or make this task depend on that one." >&2; exit 2
            fi
        done
    done
done
exit 0
```

`chmod +x hooks/task-created-check`. Add `set +f` after the loops. Note the upstream exemption: a task that lists a file owned by a task it is `blockedBy` is legal per the spec; implement it by reading the new task's own `blockedBy` from the payload if present (`json_field "$input" "blockedBy"` yields nothing for arrays with this parser — ponytail: the TaskCreated payload has no blockedBy, dependencies are added after creation, so "upstream" reduces to "not open at the same time"; document this in the header comment).

- [ ] **Step 4: Run tests; expect the task-created-check assertions to PASS**

Run: `bash tests/hooks/test-team-hooks.sh`
Expected: all task-created-check lines `[PASS]`.

- [ ] **Step 5: Write the failing tests for teammate-idle-claim**

Append after the task-created-check block:

```bash
echo "Team hooks: teammate-idle-claim"

# assert_stderr DESCRIPTION EXPECTED_EXIT GREP_PATTERN STDIN_JSON [ENV...] -- HOOK
assert_stderr() {
    local description="$1" expected="$2" pattern="$3" stdin_json="$4"; shift 4
    local env_args=(); while [ "$1" != "--" ]; do env_args+=("$1"); shift; done; shift
    local actual=0 output
    output="$(printf '%s' "$stdin_json" | env -i PATH="${PATH:-}" "${env_args[@]}" "$@" 2>&1)" || actual=$?
    if [ "$actual" -eq "$expected" ] && printf '%s' "$output" | grep -q -- "$pattern"; then pass "$description"; else fail "$description (exit $actual: $output)"; fi
}
teams_dir="$TEST_ROOT/teams"; mkdir -p "$teams_dir/t"
cat > "$teams_dir/t/config.json" <<'EOF'
{"name":"t","members":[{"name":"team-lead","agentType":"team-lead"},{"name":"hyp-3","agentType":"superteam:researcher"},{"name":"reviewer-1","agentType":"superteam:reviewer"},{"name":"integrator-1","agentType":"superteam:integrator"},{"name":"anna","agentType":"superteam:implementer"}]}
EOF
cat > "$tasks_dir/4.json" <<'EOF'
{"id":"4","subject":"Task 5: implement [implementer]","description":"Files owned: skills/z\nDone: report","status":"pending","owner":"","blockedBy":[]}
EOF
cat > "$tasks_dir/5.json" <<'EOF'
{"id":"5","subject":"Task 6: implement [implementer]","description":"Files owned: skills/w\nDone: report","status":"pending","owner":"","blockedBy":["4"]}
EOF
idle='{"teammate_name":"anna","team_name":"t"}'
E=(SUPERTEAM_TASKS_DIR="$tasks_dir" SUPERTEAM_TEAMS_DIR="$teams_dir")
assert_stderr "idle implementer (role from team config agentType) is told to claim the first unblocked pending implementer task" 2 'claim "Task 5: implement \[implementer\]"' "$idle" "${E[@]}" -- "$IDLE_HOOK"
assert_exit "idle reviewer with only blocked reviewer tasks stays idle" 0 '{"teammate_name":"reviewer-1","team_name":"t"}' "${E[@]}" -- "$IDLE_HOOK"
assert_exit "idle integrator with no integrator tasks stays idle" 0 '{"teammate_name":"integrator-1","team_name":"t"}' "${E[@]}" -- "$IDLE_HOOK"
assert_exit "idle researcher never gets an implementer task" 0 '{"teammate_name":"hyp-3","team_name":"t"}' "${E[@]}" -- "$IDLE_HOOK"
assert_exit "teammate absent from team config stays idle" 0 '{"teammate_name":"ghost","team_name":"t"}' "${E[@]}" -- "$IDLE_HOOK"
assert_stderr "SUPERTEAM_ROLE_<NAME> supplies the role when config has none" 2 'claim "Task 5' '{"teammate_name":"bob-2","team_name":"t"}' "${E[@]}" SUPERTEAM_ROLE_BOB_2=implementer -- "$IDLE_HOOK"
assert_exit "missing tasks dir stays idle" 0 "$idle" SUPERTEAM_TASKS_DIR="$TEST_ROOT/nope" SUPERTEAM_TEAMS_DIR="$teams_dir" -- "$IDLE_HOOK"
assert_exit "SUPERTEAM_SKIP_VERIFY_GATE=1 bypasses teammate-idle-claim" 0 "$idle" "${E[@]}" SUPERTEAM_SKIP_VERIFY_GATE=1 -- "$IDLE_HOOK"
assert_exit "malformed JSON exits 0" 0 '{{' -- "$IDLE_HOOK"
```

Also extend the `hooks.json wiring` python check to require all three keys: `TaskCreated`, `TeammateIdle`, `TaskCompleted`.

- [ ] **Step 6: Run tests; expect the idle assertions and the wiring assertion to FAIL**

Run: `bash tests/hooks/test-team-hooks.sh`

- [ ] **Step 7: Write `hooks/teammate-idle-claim`**

```bash
#!/usr/bin/env bash
# TeammateIdle hook for superteam. Role-aware: derives the idle teammate's
# role from the team config member's agentType ("superteam:<role>") at
# ${SUPERTEAM_TEAMS_DIR:-~/.claude/teams}/<team_name>/config.json, else
# SUPERTEAM_ROLE_<NAME>; if a pending, unowned,
# unblocked "Task N:" task tagged with that role exists, exits 2 with
# 'claim "<subject>"' so the teammate keeps working. Never names another
# role's task. Fails open (exit 0) on anything unexpected.
usage() {
    cat <<'EOF'
Usage: teammate-idle-claim
TeammateIdle hook: exits 2 with 'claim "<subject>"' when a pending, unowned,
unblocked "Task N:" task of the idle teammate's role exists; else exit 0.
Reads the TeammateIdle JSON payload from stdin.
Set SUPERTEAM_SKIP_VERIFY_GATE=1 to bypass this hook.
EOF
}
[ "${1:-}" = "--help" ] && { usage; exit 0; }
[ "${SUPERTEAM_SKIP_VERIFY_GATE:-}" = "1" ] && exit 0
input="$(cat 2>/dev/null || true)"
json_field() { printf '%s' "$1" | tr '\n' ' ' | sed -n 's/.*"'"$2"'"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1; }
json_unescape() { printf '%s' "$1" | sed -e 's/\\n/\
/g' -e 's/\\"/"/g' -e 's/\\\\/\\/g'; }
name="$(json_field "$input" "teammate_name")"
[ -n "$name" ] || exit 0
team="$(json_field "$input" "team_name")"
cfg="${SUPERTEAM_TEAMS_DIR:-$HOME/.claude/teams}/$team/config.json"
role=""
if [ -f "$cfg" ]; then
    # member object for this name -> its agentType; superteam:<role> -> <role>
    role="$(tr '\n' ' ' < "$cfg" | sed -n 's/.*"name"[[:space:]]*:[[:space:]]*"'"$name"'"[^}]*"agentType"[[:space:]]*:[[:space:]]*"superteam:\([a-z]*\)".*/\1/p' | head -1)"
fi
if [ -z "$role" ]; then
    envname="SUPERTEAM_ROLE_$(printf '%s' "$name" | tr 'a-z-' 'A-Z_')"
    role="$(printenv "$envname" 2>/dev/null || true)"
fi
case "$role" in implementer|writer|reviewer|integrator|researcher|skeptic) ;; *) exit 0 ;; esac
dir="${SUPERTEAM_TASKS_DIR:-$HOME/.claude/tasks/${CLAUDE_CODE_TASK_LIST_ID:-$team}}"
[ -d "$dir" ] || exit 0
is_done() { # id -> 0 if that task file is completed (or missing)
    local f="$dir/$1.json"; [ -f "$f" ] || return 0
    [ "$(json_field "$(cat "$f" | tr '\n' ' ')" "status")" = "completed" ]
}
for f in $(ls "$dir"/*.json 2>/dev/null | sort -t/ -k1 -n); do
    t="$(cat "$f" | tr '\n' ' ')"
    [ "$(json_field "$t" "status")" = "pending" ] || continue
    [ -z "$(json_field "$t" "owner")" ] || continue
    subj="$(json_unescape "$(json_field "$t" "subject")")"
    printf '%s' "$subj" | grep -qE "^Task [0-9]+:.*\[$role\]$" || continue
    blocked=0
    for dep in $(printf '%s' "$t" | sed -n 's/.*"blockedBy"[[:space:]]*:[[:space:]]*\[\([^]]*\)\].*/\1/p' | tr -d '" ' | tr ',' ' '); do
        is_done "$dep" || { blocked=1; break; }
    done
    [ "$blocked" -eq 0 ] || continue
    echo "claim \"$subj\" — TaskUpdate owner=$name status=in_progress, then do it." >&2
    exit 2
done
exit 0
```

`chmod +x hooks/teammate-idle-claim`. Ordering: task files are named by numeric id; sort numerically so the lowest id wins. The sed for `agentType` assumes `name` precedes `agentType` inside one member object (it does in 2.1.263 configs); if the name appears in an earlier member's field the `[^}]*` bound keeps the match inside one object.

- [ ] **Step 7a: json_field survives escaped quotes (all three hooks)**

`json_field` stops at the first `\"` inside a value, so a `Verified:` line after any quoted word in the description is invisible (found in a spike: a description containing `"Hooks"` never passed the gate). In each hook, before extracting, replace the two-character sequence backslash-quote with a placeholder that cannot occur in JSON text, e.g. `sed 's/\\"/\x01/g'` (BSD sed: use a literal control char via `$(printf '\001')`), extract with the existing `[^"]*` pattern, then map the placeholder back to `"` in `json_unescape`. Test: a TaskCompleted payload whose description is `"see the \"Hooks\" section\nVerified: ran tests"` → exit 0; the same payload without the Verified line → exit 2.

- [ ] **Step 7b: task-completed-verify takes N from the subject**

Before the `digits=` line add: `subj_n="$(printf '%s' "$task_subject" | sed -n 's/^Task \([0-9]*\):.*/\1/p')"` and loop `for n in "$subj_n" "$digits" "$digits_stripped"` (skip empty). Add one assertion: subject `Task 4: implement [implementer]` with `task_id` `17` and a report at `task-4-report.md` → exit 0. Existing 11 assertions stay green.

- [ ] **Step 8: Wire hooks.json**

Add, beside `TaskCompleted`, with the same shape (`"shell": "bash"`, command via `run-hook.cmd`):

```json
"TaskCreated": [{"hooks": [{"type": "command", "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/run-hook.cmd\" task-created-check", "shell": "bash"}]}],
"TeammateIdle": [{"hooks": [{"type": "command", "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/run-hook.cmd\" teammate-idle-claim", "shell": "bash"}]}]
```

Check `hooks/run-hook.cmd` accepts any hook name (it runs `hooks/$1`); do not edit it.

- [ ] **Step 9: Run the full hook tests; expect PASS**

Run: `bash tests/hooks/test-team-hooks.sh && bash tests/hooks/test-session-start.sh`
Expected: both `STATUS: PASSED`.

- [ ] **Step 10: Commit**

```bash
git add hooks/task-created-check hooks/teammate-idle-claim hooks/hooks.json tests/hooks/test-team-hooks.sh
git commit -m "Hooks: TaskCreated shape/overlap check and role-aware TeammateIdle claim nudge"
```

---

### Task 2: `task-brief --taskcreate`

**Files owned:** `skills/superteam-driven-development/scripts/task-brief`, `tests/claude-code/test-dispatch-template.sh`
**Depends on:** none
**Model tier:** standard

**Files:**
- Modify: `skills/superteam-driven-development/scripts/task-brief`
- Test: `tests/claude-code/test-dispatch-template.sh`

**Interfaces:**
- Consumes: a plan file whose tasks have `**Files owned:**`, `**Depends on:**`, `**Model tier:**` header lines and a `## Global Constraints` section; `--print` mode (unchanged).
- Produces: `task-brief --taskcreate PLAN_FILE N KIND [LANE]` where KIND ∈ `implement|review|merge`, LANE defaults to the current branch. Prints to stdout the subject on line 1 (`Subject: Task N: implement [implementer]`), a blank line, then the description: `Reviews:`/`Rubric:` (review) or `Merge:` (merge), then `Plan:`/`Spec:`, `Lane:`, `Worktree:`, `Files owned:`, `Done:`, `## Task Brief`, `## Global Constraints`. No `Role:` (the subject tag carries it) and no `Model:` (the pool's model is set at spawn). Role for `implement` is `[writer]` when the task's `**Model tier:**` line contains the word `prose`, else `[implementer]`.
- Ordering note: Task 4 edits files this test greps but only appends assertions here; Task 4 keeps the grepped strings, so both worktrees pass the test independently and the integrator's full run after each merge is the check.

- [ ] **Step 1: Write the failing test**

Append to `tests/claude-code/test-dispatch-template.sh` inside the existing test function, using the plan fixture the file already builds (add `**Files owned:**`, `**Depends on:**`, `**Model tier:**` lines to that fixture if absent):

```bash
    tc="$("$TASK_BRIEF" --taskcreate "$plan" 1 implement lane/x)"
    if printf '%s\n' "$tc" | sed -n 1p | grep -q '^Subject: Task 1: implement \[implementer\]$'; then pass "--taskcreate implement subject carries role tag"; else fail "--taskcreate implement subject carries role tag"; fi
    for line in '^Lane: lane/x$' '^Worktree: task-1-impl' '^Files owned: ' '^Done: report at \.superteam/sdd/' '^## Task Brief$' '^## Global Constraints$'; do
        # the Task 1 fixture must declare **Files owned:** for the Files owned assertion to be meaningful
        if printf '%s\n' "$tc" | grep -q "$line"; then pass "--taskcreate body has $line"; else fail "--taskcreate body has $line"; fi
    done
    tr="$("$TASK_BRIEF" --taskcreate "$plan" 1 review lane/x)"
    if printf '%s\n' "$tr" | grep -q '^Subject: Task 1: review \[reviewer\]$' && printf '%s\n' "$tr" | grep -q '^Reviews: worktree-task-1-impl$'; then pass "--taskcreate review subject and Reviews: line"; else fail "--taskcreate review subject and Reviews: line"; fi
    tm="$("$TASK_BRIEF" --taskcreate "$plan" 1 merge lane/x)"
    if printf '%s\n' "$tm" | grep -q '^Subject: Task 1: merge \[integrator\]$' && printf '%s\n' "$tm" | grep -q '^Merge: worktree-task-1-impl → lane/x$'; then pass "--taskcreate merge subject and Merge: line"; else fail "--taskcreate merge subject and Merge: line"; fi
    if "$TASK_BRIEF" --taskcreate "$plan" 1 bogus lane/x >/dev/null 2>&1; then fail "--taskcreate rejects unknown kind"; else pass "--taskcreate rejects unknown kind"; fi
```

- [ ] **Step 2: Run; expect FAIL**

Run: `bash tests/claude-code/test-dispatch-template.sh`

- [ ] **Step 3: Implement `--taskcreate`**

Add a third mode to `task-brief` after the `--print` parsing:

```bash
if [ "${1:-}" = "--taskcreate" ]; then
  shift
  [ $# -ge 3 ] && [ $# -le 4 ] || { echo "usage: task-brief --taskcreate PLAN_FILE TASK_NUMBER implement|review|merge [LANE]" >&2; exit 2; }
  plan=$1; n=$2; kind=$3; lane=${4:-$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo main)}
  [ -f "$plan" ] || { echo "no such plan file: $plan" >&2; exit 2; }
  case "$kind" in implement|review|merge) ;; *) echo "kind must be implement, review or merge" >&2; exit 2 ;; esac
  brief=$(awk -v n="$n" '/^```/ { infence = !infence } !infence && /^#+[ \t]+Task[ \t]+[0-9]+/ { intask = ($0 ~ ("^#+[ \t]+Task[ \t]+" n "([^0-9]|$)")) } intask { print }' "$plan")
  [ -n "$brief" ] || { echo "task ${n} not found in ${plan}" >&2; exit 3; }
  constraints=$(awk '/^## Global Constraints/ {on=1; next} on && /^(## |---)/ {exit} on {print}' "$plan")
  owned=$(printf '%s\n' "$brief" | sed -n 's/^\*\*Files owned:\*\*[[:space:]]*//p' | head -1 | tr -d '`')
  tier=$(printf '%s\n' "$brief" | sed -n 's/^\*\*Model tier:\*\*[[:space:]]*//p' | head -1)
  role=implementer; if printf '%s' "$tier" | grep -qw prose; then role=writer; fi
  spec=$(sed -n 's/^\*\*Spec:\*\*[[:space:]]*//p' "$plan" | head -1 | tr -d '`'); [ -n "$spec" ] || spec=none
  base=$(basename "$plan" .md); wt="task-${n}-impl"
  case "$kind" in
    implement) echo "Subject: Task ${n}: implement [${role}]"; echo ;;
    review)    echo "Subject: Task ${n}: review [reviewer]"; echo; echo "Reviews: worktree-${wt}"; echo "Rubric: skills/superteam-driven-development/task-reviewer-prompt.md" ;;
    merge)     echo "Subject: Task ${n}: merge [integrator]"; echo; echo "Merge: worktree-${wt} → ${lane}" ;;
  esac
  echo "Plan: ${plan}   Spec: ${spec}"
  echo "Lane: ${lane}"
  echo "Worktree: ${wt}        (EnterWorktree name; branch worktree-${wt})"
  echo "Files owned: ${owned}"
  case "$kind" in
    implement) echo "Done: report at .superteam/sdd/${base}/task-${n}-report.md with a \`Tests:\` line" ;;
    review)    echo "Done: verdict in .superteam/sdd/${base}/task-${n}-review.md with a \`Verified:\` line" ;;
    merge)     echo "Done: merge sha of worktree-${wt} into ${lane} with a \`Tests:\` line from the full suite" ;;
  esac
  echo "## Task Brief"; printf '%s\n' "$brief"
  echo "## Global Constraints"; printf '%s\n' "$constraints"
  exit 0
fi
```

Update the usage text and header comment to list the third mode.

- [ ] **Step 4: Run; expect PASS (and `test-sdd-workspace.sh` still PASS)**

Run: `bash tests/claude-code/test-dispatch-template.sh && bash tests/claude-code/test-sdd-workspace.sh`

- [ ] **Step 5: Commit**

```bash
git add skills/superteam-driven-development/scripts/task-brief tests/claude-code/test-dispatch-template.sh
git commit -m "task-brief --taskcreate emits TaskCreate subject+body for implement/review/merge"
```

---

### Task 3: Agent bodies — self-sufficient, self-claiming

**Files owned:** `agents/implementer.md`, `agents/writer.md`, `agents/reviewer.md`, `agents/integrator.md`, `agents/researcher.md`, `agents/skeptic.md`, `tests/claude-code/test-agent-roster.sh`
**Depends on:** none
**Model tier:** most capable

**Files:**
- Modify: all six `agents/*.md`
- Test: `tests/claude-code/test-agent-roster.sh`

**Interfaces:**
- Consumes: task description fields from Task 2's emitter (`Role:`, `Lane:`, `Worktree:`, `Files owned:`, `Model:`, `Done:`, `Reviews:`, `Merge:`), hook messages from Task 1 (`claim "<subject>"`).
- Produces: the claim rule paragraph (verbatim below) that Task 4's prompt files reference by name ("the claim rule in your agent body"); teammate name prefixes.

Frontmatter after this task:

| agent | model | effort | maxTurns | memory | tools / disallowedTools | isolation |
| --- | --- | --- | --- | --- | --- | --- |
| implementer | sonnet | medium | 60 | — | `tools: Read, Edit, Write, Bash, Glob, Grep, Skill, EnterWorktree, ExitWorktree` | worktree |
| writer | sonnet | medium | 60 | — | same as implementer | worktree |
| reviewer | sonnet | high | 30 | project | `disallowedTools: Edit, Write, NotebookEdit` | — |
| integrator | sonnet | medium | 20 | — | `tools: Bash, Read, Glob, Grep, Edit` | — |
| researcher | sonnet | medium | 30 | — | `disallowedTools: Edit, Write, NotebookEdit` | — |
| skeptic | opus | high | 30 | project | `disallowedTools: Edit, Write, NotebookEdit` | — |

The claim rule, verbatim in every body under `## Claiming work (teammate)`:

> As a teammate, `TaskList` and claim (`TaskUpdate` owner=<your name>, status=in_progress) the first pending, unowned, unblocked task whose subject ends with `[<role>]`; a task the lead assigned or named to you comes first; `TaskGet` its description — that is your whole brief. Never claim another role's tag; if `TaskUpdate` shows a different owner, drop it and rescan. Complete only once the `Done:` line is satisfied — first `TaskUpdate` the description to append a `Verified: <command and result>` line (that line is the completion gate's evidence; a report file inside a worktree is invisible to the gate); when nothing matches, end your turn — your last message is your report and the idle hook re-prompts you when a task of your role unblocks. Never edit `~/.claude/tasks/**` or `~/.claude/teams/**` by hand.

Split-pane rule: every body must open with one paragraph that says who the agent is and what its inputs are, because in split-pane mode the body replaces the system prompt and no dispatch template reaches it.

- [ ] **Step 1: Write the failing roster tests**

Add to `tests/claude-code/test-agent-roster.sh`:

```bash
for role in implementer writer reviewer integrator researcher skeptic; do
    f="$REPO_ROOT/agents/$role.md"
    grep -q '^maxTurns: [0-9]' "$f" && pass "agents/$role.md sets maxTurns" || fail "agents/$role.md sets maxTurns"
    grep -q '^## Claiming work (teammate)' "$f" && pass "agents/$role.md carries the claim rule" || fail "agents/$role.md carries the claim rule"
    grep -q "ends with \`\[$role\]\`" "$f" && pass "agents/$role.md claim rule names its own role tag" || fail "agents/$role.md claim rule names its own role tag"
    grep -qi 'never edit `~/.claude/tasks/\*\*`' "$f" && pass "agents/$role.md forbids hand-editing tasks" || fail "agents/$role.md forbids hand-editing tasks"
    grep -q 'model: inherit' "$f" && fail "agents/$role.md must not use model: inherit" || pass "agents/$role.md has an explicit model"
done
for role in implementer writer; do
    grep -q '^tools: .*EnterWorktree, ExitWorktree' "$REPO_ROOT/agents/$role.md" && pass "agents/$role.md allows EnterWorktree/ExitWorktree" || fail "agents/$role.md allows EnterWorktree/ExitWorktree"
    grep -q '^## Isolating (teammate)' "$REPO_ROOT/agents/$role.md" && pass "agents/$role.md has the Isolating section" || fail "agents/$role.md has the Isolating section"
    grep -q 'first command inside it is `git merge' "$REPO_ROOT/agents/$role.md" && pass "agents/$role.md merges the lane first" || fail "agents/$role.md merges the lane first"
done
for role in reviewer skeptic; do
    grep -q '^memory: project' "$REPO_ROOT/agents/$role.md" && pass "agents/$role.md has memory: project" || fail "agents/$role.md has memory: project"
done
```

- [ ] **Step 2: Run; expect FAIL**

Run: `bash tests/claude-code/test-agent-roster.sh`

- [ ] **Step 3: Rewrite `agents/implementer.md`**

Structure (same for writer, with "prose" in place of "code" and `Verified:` in place of `Tests:` where the writer's report line differs):

1. Opening paragraph: "You are an implementer on a team (role tag `[implementer]`, teammate names `impl-1`, `impl-2`…). Your brief is either the dispatch prompt (subagent) or a task description on the shared list (teammate). Both carry `Files owned:`, `Lane:`, `Worktree:`, `Done:`, `## Task Brief`, `## Global Constraints`." 
2. `## Claiming work (teammate)` — the verbatim rule above with `<role>` replaced by this file's role, so the text reads ``ends with `[implementer]` ``.
3. `## Isolating (teammate)`: after claiming, `EnterWorktree` with the `Worktree:` name from the description; the exact sentence "first command inside it is `git merge <Lane>`" must appear; do everything there; before completing, `ExitWorktree` keeping the worktree (the integrator removes it). As a subagent with `isolation: worktree` you are already isolated; skip this section.
4. Existing numbered work rules 2–8 (keep the guard section and the "relative paths" text verbatim — `tests/claude-code/test-dispatch-template.sh` greps `relative to your cwd` and `mkdir -p` in the prompt file, not here, but keep them anyway).
5. `## Report`: existing final-report order; report file at `.superteam/sdd/<plan>/task-N-report.md`; ends with `Tests:` line; as a teammate, complete the task after the file is written.
6. `## Never`: existing list plus "run anything with `background`", "spawn teammates or a nested team (foreground subagents only)", "edit `~/.claude/tasks/**` or `~/.claude/teams/**` by hand", "end a turn with a command running".
7. Last line: "As a teammate you run at the lead's effort, not this file's `effort`; Claude Code adds SendMessage, the Task tools and the worktree tools when the lead has them; the `skills` field is ignored — invoke skills by name with `Skill`."

Delete the old `## Shared task list` section and the old "When spawned as a teammate…" line.

- [ ] **Step 4: Rewrite `agents/writer.md`** the same way (role tag `[writer]`, prefix `writer-`).

- [ ] **Step 5: Rewrite `agents/reviewer.md`**

Add the opening paragraph (role tag `[reviewer]`, prefix `reviewer-`), the claim rule, and `## Reviewing a task from the list`: the description's `Reviews: worktree-task-N-impl` names the branch; produce the diff with `git diff <Lane>..worktree-task-N-impl` from the lead's checkout (you do not enter the worktree); write the verdict to `.superteam/sdd/<plan>/task-N-review.md` with a `Verified:` line naming the one focused test you ran (or "read-only review"), then complete. Frontmatter: add `maxTurns: 30`, `memory: project`. Keep "mentions SendMessage" (roster test greps it).

- [ ] **Step 6: Rewrite `agents/integrator.md`**

Opening paragraph (role tag `[integrator]`, prefix `integrator-`), claim rule, `## Merging from the list`: parse `Merge: worktree-task-N-impl → <lane>`; from the lead's checkout: `git checkout <lane>`, `git merge --no-ff worktree-task-N-impl`, run the suite named in Global Constraints, `git worktree remove --force .claude/worktrees/task-N-impl`, `git branch -d worktree-task-N-impl`; complete with `Tests:` line and merge sha in the completion message. Frontmatter `maxTurns: 20`.

- [ ] **Step 7: Rewrite `agents/researcher.md` and `agents/skeptic.md`**

Opening paragraphs (tags `[researcher]`/`[skeptic]`, prefixes `researcher-`/`skeptic-`), claim rule, `maxTurns: 30`; skeptic `memory: project` (remember kill patterns across sessions; never store repo secrets). Researcher in systematic-debugging team mode: `## Disproving peers` — read `~/.claude/teams/<team>/config.json` `members` for sibling `hyp-N` names, `SendMessage` a peer when your evidence contradicts its hypothesis, report survivors to the lead.

- [ ] **Step 8: Run; expect PASS, and validate the frontmatter fields**

Run: `bash tests/claude-code/test-agent-roster.sh && claude plugin validate .`
Expected: roster PASS; validate reports no error on `maxTurns` or `memory` (both are documented plugin-agent frontmatter fields; if validate rejects one, report BLOCKED with the exact message — do not remove the field silently).

- [ ] **Step 9: Commit**

```bash
git add agents/ tests/claude-code/test-agent-roster.sh
git commit -m "Agents: self-sufficient bodies with role-scoped self-claim, worktree steps, maxTurns/memory"
```

---

### Task 4: superteam-driven-development — task graph process

**Files owned:** `skills/superteam-driven-development/SKILL.md`, `skills/superteam-driven-development/implementer-prompt.md`, `skills/superteam-driven-development/task-reviewer-prompt.md`, `skills/superteam-driven-development/re-review-prompt.md`, `tests/claude-code/test-superteam-driven-development.sh`
**Depends on:** none
**Model tier:** most capable (prose)

**Files:**
- Modify: the four skill files and the test.

**Interfaces:**
- Consumes: `task-brief --taskcreate PLAN N implement|review|merge [LANE]` (Task 2), hook names `task-created-check`, `teammate-idle-claim`, `task-completed-verify` (Task 1), agent bodies' claim rule (Task 3).
- Produces: the section names other skills point at: `## Modes`, `## Task graph`, `## Role pool`, `## Monitor loop`, `## Restart`, `## Fallback`.

Keep these strings, which existing tests grep: `TaskCreate`, `addBlockedBy`, `Task tools absent` (SKILL.md); `Tests:`, `relative to your cwd`, `mkdir -p` (implementer-prompt.md); `re-review-prompt.md` unchanged in the strings `tests/claude-code/test-dispatch-template.sh` checks (`grep -n` that test for the exact list before editing).

- [ ] **Step 1: Write the failing test**

Append to `tests/claude-code/test-superteam-driven-development.sh` (same `assert_contains` helper):

```bash
for s in "## Modes" "## Task graph" "## Role pool" "## Monitor loop" "## Restart" "## Fallback" "task-brief --taskcreate" "Task N: implement" "Task N: review" "Task N: merge" "settings.local.json" "shutdown_request" "never implements"; do
    assert_contains "$(cat "$SKILL_DIR/SKILL.md")" "$s" "SKILL.md has $s" && pass "SKILL.md has $s" || fail "SKILL.md has $s"
done
```

(Adapt to the helper's real signature — read the top of the test file first.)

- [ ] **Step 2: Run; expect FAIL**

Run: `bash tests/claude-code/test-superteam-driven-development.sh`

- [ ] **Step 3: Rewrite SKILL.md**

Replace `## Setup`, `## Ledger`, `## The Task Loop` and `## The Process` graph with:

- `## Modes` — the spec's "Modes" paragraph verbatim; the lead states the mode once. Team mode requires split-pane teammates (`teammateMode: "tmux"` in the repo's `.claude/settings.local.json` or `--teammate-mode tmux`), because an in-process teammate's `EnterWorktree` moves the whole session's cwd; in-process teammates are only for roles that never enter a worktree (reviewer, integrator, researcher, skeptic).
- `## Setup` — lane branch and workspace (keep the existing text); then in team mode: pre-approval (write the allow-list of the plan's test/lint/git commands to `.claude/settings.local.json`; ask the lead before touching committed `.claude/settings.json`; never `--dangerously-skip-permissions`; never ask a peer session to run a command you were denied); build the graph; spawn the role pool; state the mode.
- `## Task graph` — the spec's table and description block (minus `Role:`/`Model:`, which the emitter does not print); the exact commands:
  ```
  scripts/task-brief --taskcreate PLAN N implement LANE   → TaskCreate(subject, description)
  scripts/task-brief --taskcreate PLAN N review LANE      → TaskCreate; TaskUpdate addBlockedBy=<implement id>
  scripts/task-brief --taskcreate PLAN N merge LANE       → TaskCreate; TaskUpdate addBlockedBy=<review id>
  for each "Depends on: M": TaskUpdate <implement N> addBlockedBy=<merge M>
  ```
  The `task-created-check` hook rejects a malformed task: fix the description and recreate. Fix rounds: `Task N: fix <r> [implementer]` blockedBy review, `Task N: review <r> [reviewer]` blockedBy fix, merge addBlockedBy the new review. Files owned on fix/review tasks repeat the family's list.
- `## Role pool` — sizing default (1 implementer + 1 reviewer + 1 integrator ≤ 6 tasks; +1 implementer per 5; cap 5; writer replaces implementer for prose plans); spawn each with a named `Agent` call, no `isolation`, `subagent_type: "superteam:<role>"`, prompt = "You are `<name>`. Your tasks are on the shared list; claim per your agent body. Lane: `<lane>`. Model: `<model>`."; names `impl-1`, `writer-1`, `reviewer-1`, `integrator-1`; model precedence spawn prompt > definition > `CLAUDE_CODE_SUBAGENT_MODEL` > lead.
- `## Monitor loop` — completion is two `TaskUpdate` calls: first the description with the `Verified:` line, then `status=completed` (a combined call that the gate rejects loses the description too); idle notification is the report; `TaskList`; nudge by name when in_progress and no commit/report after one monitor pass; reassign by resetting to pending and messaging; on a review verdict create fix/review pairs; rulings still go to `progress.md`; the lead never implements, never claims an implement/review/merge task. Keep the existing fix-loop breaker (5 rounds) and the rulings text.
- `## Restart` — the spec's restart paragraph.
- `## Fallback` — "Task tools absent, teams off, or `-p`": the current 6.10.0 text (worktree subagents, lead claims/completes, plan-file ledger) moved here verbatim.
- Update the dot graph so nodes read "Lead creates Task N graph", "implementer self-claims, EnterWorktree, git merge lane", "reviewer self-claims", "integrator self-claims, merges", and the fix-round nodes.
- `## Finish` — point to finishing-a-development-branch "Team teardown".

- [ ] **Step 4: Update the three prompt files**

`implementer-prompt.md`: header note "Team mode: this template is NOT sent — the task description from `task-brief --taskcreate` is the brief and the agent body carries the rules. Fallback mode: send this template as before." Keep body. `task-reviewer-prompt.md`: replace the claim line (line ~24) with "Team mode: you claimed `Task N: review [reviewer]`; the description's `Reviews:` line names the branch." `re-review-prompt.md`: same note for `Task N: review <r>`.

- [ ] **Step 5: Run; expect PASS (plus dispatch-template test unchanged)**

Run: `bash tests/claude-code/test-superteam-driven-development.sh && bash tests/claude-code/test-dispatch-template.sh && bash tests/claude-code/test-superteam-driven-development-integration.sh`

- [ ] **Step 6: Commit**

```bash
git add skills/superteam-driven-development tests/claude-code/test-superteam-driven-development.sh
git commit -m "SDD: task graph with role-scoped self-claim; 6.10.0 path kept as Fallback"
```

---

### Task 5: Team modes in four skills + team teardown

**Files owned:** `skills/requesting-code-review/SKILL.md`, `skills/systematic-debugging/SKILL.md`, `skills/brainstorming/SKILL.md`, `skills/dispatching-parallel-agents/SKILL.md`, `skills/finishing-a-development-branch/SKILL.md`
**Depends on:** none
**Model tier:** standard (prose)

**Files:** modify the five SKILL.md files; no test file (the existing `tests/claude-code/test-worktree-path-policy.sh` greps finishing-a-development-branch — run it).

**Interfaces:**
- Consumes: teammate names `review-spec`, `review-standards`, `lens-<name>`, `hyp-N`, `skeptic-1`; `shutdown_request` message shape `{"type":"shutdown_request","reason":"…"}`; `~/.claude/teams/<team>/config.json` members.
- Produces: a `## Team mode` section in each of the four skills and `## Team teardown` in finishing-a-development-branch.

Each `## Team mode` section is ≤ 25 lines and starts with the one-line detect test ("TaskCreate in your tools, teams on, interactive — else use the fallback below") and ends with a `**Fallback:**` line that names today's subagent dispatch unchanged.

- [ ] **Step 1: requesting-code-review** — after the two-axis section: spawn `review-spec` and `review-standards` as reviewer teammates (named `Agent`, no isolation) with the two existing prompt files; optional `lens-<name>` reviewers (security, performance, a11y) each with one lens sentence; lead concatenates in spawn order, no reranking; each reviewer completes its own review task when the list is live. Fallback: two subagents as today.
- [ ] **Step 2: systematic-debugging** — in the hypothesis phase: 3–5 `hyp-N` researcher teammates, one hypothesis each in the prompt, instructed "read `~/.claude/teams/<team>/config.json` for your peers; when your evidence contradicts a peer's hypothesis, `SendMessage` it with the evidence; report which hypotheses survived"; lead keeps survivors. Fallback: sequential researcher subagents.
- [ ] **Step 3: brainstorming** — in "Offer the skeptic pass": in team mode the offer may spawn `skeptic-1` as a live teammate that stays for the session and re-runs on each revised approach; fallback: skeptic subagent per pass.
- [ ] **Step 4: dispatching-parallel-agents** — replace the "With Task tools present" paragraph: one pool of one role, one task per unit created with `Files owned:` and `Done:` lines (the TaskCreated hook requires both for `Task N:` subjects; for non-`Task N:` subjects nothing is gated), teammates self-claim per their body; fallback unchanged.
- [ ] **Step 5: finishing-a-development-branch** — add `## Team teardown` before the merge options: when a role has no pending tasks, `SendMessage` `{"type":"shutdown_request","reason":"role pool empty"}` to each idle teammate of that role; after all merges: merge lane → trunk, then shut down the rest; confirm `~/.claude/teams/<team>/config.json` lists no live members before deleting the workspace.
- [ ] **Step 6: Run** `bash tests/claude-code/test-worktree-path-policy.sh && bash tests/claude-code/run-skill-tests.sh` — expect PASS.
- [ ] **Step 7: Commit**

```bash
git add skills/requesting-code-review skills/systematic-debugging skills/brainstorming skills/dispatching-parallel-agents skills/finishing-a-development-branch
git commit -m "Team modes: review, debugging, brainstorming, parallel pools; team teardown"
```

---

### Task 6: using-superteam Step 0, README, references, session-start

**Files owned:** `skills/using-superteam/SKILL.md`, `skills/using-superteam/references/claude-code-tools.md`, `README.md`, `hooks/session-start`, `tests/hooks/test-session-start.sh`
**Depends on:** none
**Model tier:** standard (prose)

**Files:** modify the five.

**Interfaces:**
- Consumes: env var names `CLAUDE_CODE_ENABLE_TODO_TOOLS`, `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`, setting `subagentPromptCacheTtl`, `teammateMode`; hook names from Task 1.
- Produces: `## Step 0: how many agents` table in using-superteam (Claude Code branch only, as injected by `hooks/session-start`).

- [ ] **Step 1: Failing test** — add to `tests/hooks/test-session-start.sh`: the Claude Code injected text contains `Step 0` and `TaskCreate`; `wc -l skills/using-superteam/SKILL.md` ≤ 67 (update any existing exact-63 assertion in that file to ≤ 67).
- [ ] **Step 2: Run** `bash tests/hooks/test-session-start.sh` — expect FAIL.
- [ ] **Step 3: SKILL.md** — insert after the `## The Rule` section (before `## Skill Priority`), exactly these 4 lines (heading, blank, one paragraph, blank):

```
## Step 0: how many agents

Team mode = `TaskCreate` in your tools + interactive (not `-p`) + `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`; otherwise foreground subagents. One answer or one file set → a subagent (`isolation: worktree` when it edits); a worker that reports and stays → a teammate (named `Agent`, no isolation); 3+ plan tasks or 3+ hypotheses → a team of 3–5 role teammates on the task graph; another repo or a second lead → a cross-session peer via `SendMessage`. Cost: one context per agent, so a team is N contexts on one shared list.
```

The full decision table lives in `references/claude-code-tools.md` (Step 4). Remove nothing else; verify `wc -l` ≤ 67.

- [ ] **Step 4: references/claude-code-tools.md** — rewrite: `## Step 0 decision table` (Need / Use / Cost rows: one answer → subagent, 1 context; a worker that stays → teammate, 1 context + mailbox; 3+ tasks or hypotheses → team of 3–5, N contexts on one list; another repo → cross-session peer PM, separate session); Task tools table (keep); availability gate (keep, fix the pilot parenthetical: `CLAUDE_CODE_TASK_LIST_ID` names the on-disk dir, verified 2.1.263); launch rule (keep); add sections `## Team files` (`~/.claude/teams/<team>/config.json` with `members`, per-teammate mailboxes, task dir `~/.claude/tasks/<list>/`; never hand-edit; teammates discover peers via config.json and may message across roles), `## Model precedence` (spawn prompt > definition `model` > `CLAUDE_CODE_SUBAGENT_MODEL` > lead), `## teammateMode` (`auto|in-process|tmux`; in split-pane/tmux mode the agent body replaces the system prompt — bodies must be self-sufficient; a split-pane teammate is its own process: it gets its env from the tmux SESSION environment, not from the lead process, so `CLAUDE_CODE_TASK_LIST_ID` must be set on the tmux session (or in settings `env`) or the teammate claims on the wrong list; Task tools arrive deferred and load via ToolSearch; Glob and Grep are absent; its permission prompts surface in the lead pane, so pre-approve in `.claude/settings.local.json`; in-process teammates share the session cwd, so `EnterWorktree` from one moves everyone), `## Effort` (frontmatter honoured for subagents, inherited for teammates), `## Known bug` (subagents never receive Task tools on 2.1.263; repro: agent with `tools: Read, TaskList` gets only Read).
- [ ] **Step 5: README.md** — in the setup section require both env vars (with a `~/.zshrc` export block), recommend `"subagentPromptCacheTtl": "1h"` in settings, team size 3–5, 5–6 tasks per teammate; update "### Agent-team hooks" to list the three hooks and what each rejects; state that other harnesses use the fallback path.
- [ ] **Step 6: hooks/session-start** — no logic change unless the Step 0 header must be stripped for other harnesses: the Claude Code branch injects SKILL.md minus "## Platform Adaptation"; other branches inject the full file. Leave as is unless the test in Step 1 fails on it.
- [ ] **Step 7: Run** `bash tests/hooks/test-session-start.sh && test "$(wc -l < skills/using-superteam/SKILL.md)" -le 67` — expect PASS.
- [ ] **Step 8: Commit**

```bash
git add skills/using-superteam README.md hooks/session-start tests/hooks/test-session-start.sh
git commit -m "using-superteam Step 0 decision table; README enable/tuning; Claude Code team reference"
```

---

### Task 7: Audit doc from primary sources

**Files owned:** `docs/superteam/plans/2026-09-05-agent-team-audit.md`
**Depends on:** none
**Model tier:** standard (prose)

**Files:** rewrite the one doc.

**Interfaces:**
- Consumes: the ten sources, fetched the same day with `curl -sL <url> -o .superteam/src/<name>.md` (gitignored scratch inside the worktree): `https://code.claude.com/docs/en/agent-teams.md`, `sub-agents.md`, `plugins-reference.md`, `tools-reference.md`, `hooks.md`, `env-vars.md`, `settings-reference.md`, `cross-session-messaging.md`, `worktrees.md`, `interactive-mode.md`.
- Produces: a table per source: feature · `source: <url>#<section>` · used where in superteam (file) · or why not.

- [ ] **Step 1: Fetch** the ten files: `mkdir -p .superteam/src` then one `curl -fsSL <url> -o .superteam/src/<name>.md` per file. If any curl exits non-zero, or `grep -c '^#' .superteam/src/<name>.md` is 0, STOP: write the report with `BLOCKED: fetch failed for <name>` and no `Tests:` line, and end your turn. Never write a table from memory.
- [ ] **Step 2: Write** the doc: header (date, harness 2.1.263, fetch time), one section per source with the table, then `## Findings`: the subagent Task-tools bug with the exact repro (agent file with `tools: Read, TaskList, TaskUpdate, TaskCreate, TaskGet`, env `CLAUDE_CODE_ENABLE_TODO_TOOLS=1 CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`, `claude -p` in a git repo, observed tools list = Read only; ToolSearch `select:TaskList` → no match), the effort finding with both citations, and the EnterWorktree spike (teammate moved, lead cwd unchanged).
- [ ] **Step 3: Verify** every `source:` citation resolves to a heading in the fetched file. Anchors are the heading text lower-cased with spaces as `-` and punctuation dropped. Run and paste into the report:

```bash
fail=0
grep -o 'source: https://code.claude.com/docs/en/[a-z-]*\.md#[a-z0-9-]*' docs/superteam/plans/2026-09-05-agent-team-audit.md | sort -u | while read -r _ url; do
  f=".superteam/src/$(basename "${url%%#*}")"; a="${url##*#}"
  if ! grep -E '^#+ ' "$f" | sed -E 's/^#+ //; s/[^A-Za-z0-9 -]//g' | tr 'A-Z ' 'a-z-' | grep -qx "$a"; then echo "MISSING $url"; fail=1; fi
done
echo "anchor check done"
```

Every `MISSING` line must be fixed before commit; the report's `Tests:` line is `Tests: anchor check — 0 MISSING of <N> citations`.
- [ ] **Step 4: Commit**

```bash
git add docs/superteam/plans/2026-09-05-agent-team-audit.md
git commit -m "Audit: agent-team features vs superteam 7.0.0, primary sources cited"
```

---

## Finish (lead)

After all seven merges into the lane: `claude plugin validate .`; run `tests/hooks/*.sh`, `tests/claude-code/run-skill-tests.sh`, `tests/kimi/test-plugin-manifest.sh`, `tests/devin/test-devin-plugin.sh`, `tests/codex/test-package-codex-plugin.sh`; `wc -l skills/using-superteam/SKILL.md` = 63; fresh `claude -p` load check of the plugin; bump the nine manifests 6.10.0 → 7.0.0; merge lane → main; `claude plugin update superteam@cameronchittick`; report sha plus claim/lag/race observations.
