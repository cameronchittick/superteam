#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
VERIFY_HOOK="$REPO_ROOT/hooks/task-completed-verify"
HOOKS_JSON="$REPO_ROOT/hooks/hooks.json"

FAILURES=0
TEST_ROOT="$(mktemp -d)"

cleanup() {
    rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

pass() {
    echo "  [PASS] $1"
}

fail() {
    echo "  [FAIL] $1"
    FAILURES=$((FAILURES + 1))
}

# task-completed-verify falls back to $PWD when the payload carries no "cwd",
# so a fake payload would find a REAL .superteam/sdd/*/task-N-report.md in the
# checkout the suite runs from and invert the assertion. Every payload without
# its own cwd gets this empty scratch directory instead.
SCRATCH_CWD="$TEST_ROOT/scratch"
mkdir -p "$SCRATCH_CWD"

# echoes the payload with "cwd" pinned to the scratch dir, unless it has one
with_scratch_cwd() {
    case "$1" in
        '{'*)
            if [ "${1#*\"cwd\"}" = "$1" ]; then
                printf '{"cwd":"%s",%s' "$SCRATCH_CWD" "${1#\{}"
                return
            fi
            ;;
    esac
    printf '%s' "$1"
}

# assert_exit DESCRIPTION EXPECTED_EXIT STDIN_JSON [EXTRA_ENV...] -- HOOK [ARGS...]
assert_exit() {
    local description="$1" expected="$2" stdin_json
    stdin_json="$(with_scratch_cwd "$3")"
    shift 3
    local env_args=()
    while [ "$1" != "--" ]; do
        env_args+=("$1")
        shift
    done
    shift # drop --

    local actual=0
    local output
    # bash 3.2 (macOS) treats an empty array expansion as unbound under set -u
    output="$(printf '%s' "$stdin_json" | env -i PATH="${PATH:-}" ${env_args[@]+"${env_args[@]}"} "$@" 2>&1)" || actual=$?

    if [ "$actual" -eq "$expected" ]; then
        pass "$description"
    else
        fail "$description (expected exit $expected, got $actual)"
        echo "$output" | sed 's/^/      /'
    fi
}

echo "Team hooks: task-completed-verify"

assert_exit \
    "SDD subject with Verified: line allows completion" \
    0 \
    '{"task_id":"4","task_subject":"Task 4: x","task_description":"did stuff\nVerified: ran tests, all pass"}' \
    -- "$VERIFY_HOOK"

assert_exit \
    "SDD subject with no evidence blocks completion" \
    2 \
    '{"task_id":"4","task_subject":"Task 4: x","task_description":"no evidence here"}' \
    -- "$VERIFY_HOOK"

report_home="$TEST_ROOT/report-home"
mkdir -p "$report_home/.superteam/sdd/agent-team"
cat > "$report_home/.superteam/sdd/agent-team/task-4-report.md" <<'EOF'
# Report
Tests: 13/13 PASS
EOF
assert_exit \
    "report file with Tests: line allows completion" \
    0 \
    "$(printf '{"task_id":"4","task_subject":"Task 4: x","task_description":"no evidence","cwd":"%s"}' "$report_home")" \
    -- "$VERIFY_HOOK"

assert_exit \
    "SUPERTEAM_SKIP_VERIFY_GATE=1 bypasses the gate" \
    0 \
    '{"task_id":"4","task_subject":"Task 4: x","task_description":"no evidence"}' \
    SUPERTEAM_SKIP_VERIFY_GATE=1 \
    -- "$VERIFY_HOOK"

assert_exit \
    "malformed JSON exits 0 (fail open, never crashes)" \
    0 \
    'not json at all {{{' \
    -- "$VERIFY_HOOK"

assert_exit \
    "non-SDD subject without evidence is never gated" \
    0 \
    '{"task_id":"1","task_subject":"Track the launch checklist","task_description":"no evidence here"}' \
    -- "$VERIFY_HOOK"

assert_exit \
    "SDD subject (Task 3: foo) without evidence blocks completion" \
    2 \
    '{"task_id":"3","task_subject":"Task 3: foo","task_description":"no evidence here"}' \
    -- "$VERIFY_HOOK"

assert_exit \
    "non-SDD subject with .superteam/sdd/ in description is still gated (2)" \
    2 \
    '{"task_id":"7","task_subject":"Coordinate work","task_description":"see .superteam/sdd/plan/task-7-report.md"}' \
    -- "$VERIFY_HOOK"

assert_exit \
    "SDD subject with Verified: in description allows completion" \
    0 \
    '{"task_id":"3","task_subject":"Task 3: foo","task_description":"Verified: ran the suite"}' \
    -- "$VERIFY_HOOK"

help_output="$("$VERIFY_HOOK" --help)"
help_lines="$(printf '%s\n' "$help_output" | wc -l | tr -d ' ')"
if [ "$help_lines" -eq 5 ]; then
    pass "task-completed-verify --help prints 5 lines"
else
    fail "task-completed-verify --help prints 5 lines (got $help_lines)"
fi

echo "Team hooks: task-completed-verify (escaped quotes, subject-derived N)"

assert_exit \
    "Verified: line after an escaped quote in the description is seen" \
    0 \
    '{"task_id":"4","task_subject":"Task 4: x","task_description":"see the \"Hooks\" section\nVerified: ran tests"}' \
    -- "$VERIFY_HOOK"

assert_exit \
    "escaped quote in the description without a Verified: line still blocks" \
    2 \
    '{"task_id":"4","task_subject":"Task 4: x","task_description":"see the \"Hooks\" section\nno evidence"}' \
    -- "$VERIFY_HOOK"

assert_exit \
    "report N comes from the subject, not the task_id" \
    0 \
    "$(printf '{"task_id":"17","task_subject":"Task 4: implement [implementer]","task_description":"no evidence","cwd":"%s"}' "$report_home")" \
    -- "$VERIFY_HOOK"

CREATED_HOOK="$REPO_ROOT/hooks/task-created-check"
IDLE_HOOK="$REPO_ROOT/hooks/teammate-idle-claim"
tasks_dir="$TEST_ROOT/tasks"
mkdir -p "$tasks_dir"
# task 1: implement, owns hooks/a; task 2: review of task 1 (same family); task 3: merge (blockedBy 2)
# task 1 is open but already owned, so it is not claimable by an idle teammate
# while still counting as an open owner of hooks/a for the overlap checks.
cat > "$tasks_dir/1.json" <<'EOF'
{"id":"1","subject":"Task 1: implement [implementer]","description":"Files owned: hooks/a, hooks/b\nDone: report with Tests: line","status":"pending","owner":"impl-1","blockedBy":[]}
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

created_help_lines="$({ "$CREATED_HOOK" --help 2>/dev/null || true; } | wc -l | tr -d ' ')"
if [ "$created_help_lines" -eq 5 ]; then
    pass "task-created-check --help prints 5 lines"
else
    fail "task-created-check --help prints 5 lines (got $created_help_lines)"
fi

echo "Team hooks: teammate-idle-claim"

# assert_stderr DESCRIPTION EXPECTED_EXIT GREP_PATTERN STDIN_JSON [ENV...] -- HOOK
assert_stderr() {
    local description="$1" expected="$2" pattern="$3" stdin_json
    stdin_json="$(with_scratch_cwd "$4")"; shift 4
    local env_args=(); while [ "$1" != "--" ]; do env_args+=("$1"); shift; done; shift
    local actual=0 output
    output="$(printf '%s' "$stdin_json" | env -i PATH="${PATH:-}" ${env_args[@]+"${env_args[@]}"} "$@" 2>&1)" || actual=$?
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

# ids are numbers, not strings: with 2 and 10 both claimable, 2 must win
ids_dir="$TEST_ROOT/ids"; mkdir -p "$ids_dir"
cat > "$ids_dir/10.json" <<'EOF'
{"id":"10","subject":"Task 10: implement [implementer]","description":"Files owned: skills/ten\nDone: report","status":"pending","owner":"","blockedBy":[]}
EOF
cat > "$ids_dir/2.json" <<'EOF'
{"id":"2","subject":"Task 2: implement [implementer]","description":"Files owned: skills/two\nDone: report","status":"pending","owner":"","blockedBy":[]}
EOF
assert_stderr "task ids are ordered numerically, so id 2 wins over id 10" 2 'claim "Task 2: implement \[implementer\]"' "$idle" SUPERTEAM_TASKS_DIR="$ids_dir" SUPERTEAM_TEAMS_DIR="$teams_dir" -- "$IDLE_HOOK"

echo "Team hooks: no repeat-nudge loops"

# TaskCompleted also fires when a teammate ends a turn with an in-progress
# task, so the same rejection can repeat forever. Second rejection of an
# unchanged state says so in one line instead of the full feedback.
gate_dir="$TEST_ROOT/gate-tasks"; mkdir -p "$gate_dir"
gate_payload='{"task_id":"4","task_subject":"Task 4: x","teammate_name":"anna","task_description":"waiting on the lead"}'
gate_payload2='{"task_id":"4","task_subject":"Task 4: x","teammate_name":"anna","task_description":"waiting on the lead, still"}'
assert_stderr "first rejection of a state gives the full feedback" 2 'No verification evidence' "$gate_payload" SUPERTEAM_TASKS_DIR="$gate_dir" -- "$VERIFY_HOOK"
assert_stderr "repeat rejection of the same state is one line" 2 'Gate already rejected this state' "$gate_payload" SUPERTEAM_TASKS_DIR="$gate_dir" -- "$VERIFY_HOOK"
assert_stderr "repeat rejection still exits 2, never silently completes" 2 'TaskUpdate status=pending' "$gate_payload" SUPERTEAM_TASKS_DIR="$gate_dir" -- "$VERIFY_HOOK"
assert_stderr "an edited description is a new state and gets the full feedback" 2 'No verification evidence' "$gate_payload2" SUPERTEAM_TASKS_DIR="$gate_dir" -- "$VERIFY_HOOK"

# The idle hook must not re-nudge for the same task while nothing has changed.
loop_dir="$TEST_ROOT/loop-tasks"; mkdir -p "$loop_dir"
cat > "$loop_dir/7.json" <<'EOF'
{"id":"7","subject":"Task 7: implement [implementer]","description":"Files owned: skills/seven\nDone: report","status":"pending","owner":"","blockedBy":[]}
EOF
L=(SUPERTEAM_TASKS_DIR="$loop_dir" SUPERTEAM_TEAMS_DIR="$teams_dir")
assert_stderr "idle hook nudges once for a new claimable task" 2 'claim "Task 7' "$idle" "${L[@]}" -- "$IDLE_HOOK"
assert_exit "idle hook does not re-nudge while nothing has changed" 0 "$idle" "${L[@]}" -- "$IDLE_HOOK"

# A teammate already holding work is never nudged.
busy_dir="$TEST_ROOT/busy-tasks"; mkdir -p "$busy_dir"
cat > "$busy_dir/1.json" <<'EOF'
{"id":"1","subject":"Task 1: implement [implementer]","description":"Files owned: skills/one\nDone: report","status":"in_progress","owner":"anna","blockedBy":[]}
EOF
cat > "$busy_dir/2.json" <<'EOF'
{"id":"2","subject":"Task 2: implement [implementer]","description":"Files owned: skills/two\nDone: report","status":"pending","owner":"","blockedBy":[]}
EOF
assert_exit "a teammate owning an in_progress task is never nudged" 0 "$idle" SUPERTEAM_TASKS_DIR="$busy_dir" SUPERTEAM_TEAMS_DIR="$teams_dir" -- "$IDLE_HOOK"

# A task the teammate declined is never offered again.
declined_dir="$TEST_ROOT/declined-tasks"; mkdir -p "$declined_dir/.declined"
cat > "$declined_dir/3.json" <<'EOF'
{"id":"3","subject":"Task 3: implement [implementer]","description":"Files owned: skills/three\nDone: report","status":"pending","owner":"","blockedBy":[]}
EOF
echo "3" > "$declined_dir/.declined/anna"
assert_exit "a declined task id is never nudged again" 0 "$idle" SUPERTEAM_TASKS_DIR="$declined_dir" SUPERTEAM_TEAMS_DIR="$teams_dir" -- "$IDLE_HOOK"

echo "Team hooks: teammate-idle-claim offers a task once, then cools down"

# task_json ID SUBJECT STATUS OWNER
task_json() {
    printf '{"id":"%s","subject":"%s","description":"Files owned: skills/t%s\\nDone: report","status":"%s","owner":"%s","blockedBy":[]}\n' "$1" "$2" "$1" "$3" "$4"
}
# dir_mtime DIR -> epoch seconds, GNU stat then BSD stat
dir_mtime() { stat -c %Y "$1" 2>/dev/null || stat -f %m "$1"; }

# A second seat writes to the tasks directory while the first seat is idle:
# the first seat is not offered its task again. The cooldown is 0 here so the
# once-per-task rule alone keeps it quiet.
once_dir="$TEST_ROOT/once-tasks"; mkdir -p "$once_dir"
task_json 7 "Task 7: implement [implementer]" pending "" > "$once_dir/7.json"
O=(SUPERTEAM_TASKS_DIR="$once_dir" SUPERTEAM_TEAMS_DIR="$teams_dir" SUPERTEAM_IDLE_COOLDOWN=0)
assert_stderr "anna is offered task 7" 2 'claim "Task 7' "$idle" "${O[@]}" -- "$IDLE_HOOK"
before_mtime="$(dir_mtime "$once_dir")"
sleep 1
task_json 8 "Task 8: review spec [reviewer]" in_progress "reviewer-1" > "$once_dir/8.json.tmp"
mv "$once_dir/8.json.tmp" "$once_dir/8.json"
if [ "$(dir_mtime "$once_dir")" != "$before_mtime" ]; then
    pass "a second seat's write moved the tasks dir mtime"
else
    fail "a second seat's write moved the tasks dir mtime"
fi
assert_exit "after a second seat writes to the tasks dir, anna is not offered task 7 again" 0 "$idle" "${O[@]}" -- "$IDLE_HOOK"

# A different task inside the cooldown stays quiet; after the cooldown a
# pending unowned task of the role is offered.
cool_dir="$TEST_ROOT/cool-tasks"; mkdir -p "$cool_dir"
task_json 1 "Task 1: implement [implementer]" pending "" > "$cool_dir/1.json"
task_json 2 "Task 2: implement [implementer]" pending "" > "$cool_dir/2.json"
C=(SUPERTEAM_TASKS_DIR="$cool_dir" SUPERTEAM_TEAMS_DIR="$teams_dir")
assert_stderr "anna is offered task 1" 2 'claim "Task 1' "$idle" "${C[@]}" -- "$IDLE_HOOK"
task_json 1 "Task 1: implement [implementer]" in_progress "bob-2" > "$cool_dir/1.json"
assert_exit "a different task inside the default cooldown stays quiet" 0 "$idle" "${C[@]}" -- "$IDLE_HOOK"
assert_exit "a different task inside a 600-second cooldown stays quiet" 0 "$idle" "${C[@]}" SUPERTEAM_IDLE_COOLDOWN=600 -- "$IDLE_HOOK"
sleep 2
assert_stderr "after the cooldown, a pending unowned task of the role is offered" 2 'claim "Task 2' "$idle" "${C[@]}" SUPERTEAM_IDLE_COOLDOWN=1 -- "$IDLE_HOOK"

# A claim resets the cooldown: it only blocks a second offer that follows an
# offer with no claim in between, so a seat that is working is never idled.
work_dir="$TEST_ROOT/work-tasks"; mkdir -p "$work_dir"
task_json 1 "Task 1: implement [implementer]" pending "" > "$work_dir/1.json"
task_json 2 "Task 2: implement [implementer]" pending "" > "$work_dir/2.json"
W=(SUPERTEAM_TASKS_DIR="$work_dir" SUPERTEAM_TEAMS_DIR="$teams_dir")
assert_stderr "anna is offered task 1 (default cooldown)" 2 'claim "Task 1' "$idle" "${W[@]}" -- "$IDLE_HOOK"
task_json 1 "Task 1: implement [implementer]" in_progress "anna" > "$work_dir/1.json"
task_json 1 "Task 1: implement [implementer]" completed "anna" > "$work_dir/1.json"
assert_stderr "a seat that claims and completes a task inside the cooldown is offered the next task at once" 2 'claim "Task 2' "$idle" "${W[@]}" -- "$IDLE_HOOK"
task_json 3 "Task 3: implement [implementer]" pending "" > "$work_dir/3.json"
assert_exit "an offer with no claim since still starts the cooldown" 0 "$idle" "${W[@]}" -- "$IDLE_HOOK"

# A lead reassigning a task by clearing its owner gets it claimed: once the
# hook has seen the task owned, the earlier offer no longer counts.
re_dir="$TEST_ROOT/reassign-tasks"; mkdir -p "$re_dir"
task_json 3 "Task 3: implement [implementer]" pending "" > "$re_dir/3.json"
R=(SUPERTEAM_TASKS_DIR="$re_dir" SUPERTEAM_TEAMS_DIR="$teams_dir" SUPERTEAM_IDLE_COOLDOWN=0)
assert_stderr "anna is offered task 3" 2 'claim "Task 3' "$idle" "${R[@]}" -- "$IDLE_HOOK"
task_json 3 "Task 3: implement [implementer]" in_progress "anna" > "$re_dir/3.json"
assert_exit "anna holding task 3 is quiet" 0 "$idle" "${R[@]}" -- "$IDLE_HOOK"
task_json 3 "Task 3: implement [implementer]" pending "" > "$re_dir/3.json"
assert_stderr "after the lead clears task 3's owner, it is offered again" 2 'claim "Task 3' "$idle" "${R[@]}" -- "$IDLE_HOOK"

bad_dir="$TEST_ROOT/bad-cooldown-tasks"; mkdir -p "$bad_dir"
task_json 4 "Task 4: implement [implementer]" pending "" > "$bad_dir/4.json"
assert_stderr "a non-numeric SUPERTEAM_IDLE_COOLDOWN falls back to the default, not an error" 2 'claim "Task 4' "$idle" SUPERTEAM_TASKS_DIR="$bad_dir" SUPERTEAM_TEAMS_DIR="$teams_dir" SUPERTEAM_IDLE_COOLDOWN=soon -- "$IDLE_HOOK"

idle_help_lines="$({ "$IDLE_HOOK" --help 2>/dev/null || true; } | wc -l | tr -d ' ')"
if [ "$idle_help_lines" -eq 5 ]; then
    pass "teammate-idle-claim --help prints 5 lines"
else
    fail "teammate-idle-claim --help prints 5 lines (got $idle_help_lines)"
fi

echo "Team hooks: task-created-check: Files owned overlap"

# An overlap is a collision only when nothing serializes the two tasks. The
# TaskCreated payload carries no blockedBy, so the description carries the
# dependency: a "Depends on: Task M" line naming the overlapping open task's
# family is the edge, and the hook accepts the overlap.
overlap_dir="$TEST_ROOT/overlap-tasks"; mkdir -p "$overlap_dir"
cat > "$overlap_dir/1.json" <<'EOF'
{"id":"1","subject":"Task 1: implement [implementer]","status":"in_progress","description":"Files owned: a.sh\nDone: x"}
EOF
O=(SUPERTEAM_TASKS_DIR="$overlap_dir")
assert_stderr "overlap with no Depends on line is rejected, naming the open task" 2 'Task 1: implement' \
    '{"task_id":"9","task_subject":"Task 2: implement [implementer]","task_description":"Files owned: a.sh\nDepends on: none\nDone: x"}' "${O[@]}" -- "$CREATED_HOOK"
assert_exit "overlap with Depends on: Task 1 is allowed" 0 \
    '{"task_id":"9","task_subject":"Task 2: implement [implementer]","task_description":"Files owned: a.sh\nDepends on: Task 1\nDone: x"}' "${O[@]}" -- "$CREATED_HOOK"
assert_exit "overlap with Depends on naming a different task is rejected" 2 \
    '{"task_id":"9","task_subject":"Task 3: implement [implementer]","task_description":"Files owned: a.sh\nDepends on: Task 2\nDone: x"}' "${O[@]}" -- "$CREATED_HOOK"
assert_exit "no overlap is allowed" 0 \
    '{"task_id":"9","task_subject":"Task 2: implement [implementer]","task_description":"Files owned: b.sh\nDepends on: none\nDone: x"}' "${O[@]}" -- "$CREATED_HOOK"
assert_exit "Depends on listing several tasks exempts each of them" 0 \
    '{"task_id":"9","task_subject":"Task 4: implement [implementer]","task_description":"Files owned: a.sh\nDepends on: Task 1, Task 7\nDone: x"}' "${O[@]}" -- "$CREATED_HOOK"

echo "Team hooks: task-brief: Depends on line"

BRIEF="$REPO_ROOT/skills/superteam-driven-development/scripts/task-brief"
fixture_plan="$TEST_ROOT/fixture-plan.md"
cat > "$fixture_plan" <<'EOF'
# Plan

**Spec:** specs/fixture.md

### Task 1: First thing

**Files owned:** `a.sh`
**Depends on:** none
**Model tier:** most capable

- [ ] Step 1: do it.

### Task 2: Second thing

**Files owned:** `a.sh`, `b.sh`
**Depends on:** Task 1
**Isolation:** worktree
**Model tier:** most capable

- [ ] Step 1: do it too.

## Global Constraints

- Zero dependencies.
EOF

for kind in implement review-spec review-standards merge; do
    brief_out="$("$BRIEF" --taskcreate "$fixture_plan" 2 "$kind" lane/x 2>&1 || true)"
    if printf '%s\n' "$brief_out" | grep -qx 'Depends on: Task 1'; then
        pass "task-brief --taskcreate $kind emits the Depends on line"
    else
        fail "task-brief --taskcreate $kind emits the Depends on line"
        printf '%s\n' "$brief_out" | sed 's/^/      /'
    fi
    if printf '%s\n' "$brief_out" | grep -A1 '^Files owned:' | grep -qx 'Depends on: Task 1'; then
        pass "task-brief --taskcreate $kind puts Depends on right after Files owned"
    else
        fail "task-brief --taskcreate $kind puts Depends on right after Files owned"
    fi
done

brief_out="$("$BRIEF" --taskcreate "$fixture_plan" 1 implement lane/x 2>&1 || true)"
if printf '%s\n' "$brief_out" | grep -qx 'Depends on: none'; then
    pass "task-brief emits 'Depends on: none' when the plan task has no dependency"
else
    fail "task-brief emits 'Depends on: none' when the plan task has no dependency"
    printf '%s\n' "$brief_out" | sed 's/^/      /'
fi

echo "Team hooks: task-created-check: review axis"

# Per-task review is two seats from the same reviewer.md: spec and standards.
# The step between "Task N:" and the role tag must name one of the known
# steps, so a bare "review" (which axis?) is a rejection, not a guess.
axis_dir="$TEST_ROOT/axis-tasks"; mkdir -p "$axis_dir"
A=(SUPERTEAM_TASKS_DIR="$axis_dir")
axis_payload() {
    printf '{"task_id":"9","task_subject":"%s","task_description":"Files owned: skills/axis\\nDepends on: none\\nDone: verdict"}' "$1"
}
for step in "implement [implementer]" "merge [integrator]" "fix 2 [implementer]" \
            "review spec [reviewer]" "review standards [reviewer]" \
            "review spec 2 [reviewer]" "review standards 2 [reviewer]"; do
    assert_exit "Task 2: $step is accepted" 0 "$(axis_payload "Task 2: $step")" "${A[@]}" -- "$CREATED_HOOK"
done
assert_stderr "bare 'Task 2: review [reviewer]' is rejected for want of an axis" 2 'axis' \
    "$(axis_payload 'Task 2: review [reviewer]')" "${A[@]}" -- "$CREATED_HOOK"
assert_stderr "an unknown step is rejected" 2 'step' \
    "$(axis_payload 'Task 2: deploy [implementer]')" "${A[@]}" -- "$CREATED_HOOK"

echo "Team hooks: teammate-idle-claim: both review axes"

axis_idle="$TEST_ROOT/axis-idle"; mkdir -p "$axis_idle"
cat > "$axis_idle/3.json" <<'EOF'
{"id":"3","subject":"Task 2: review spec [reviewer]","description":"Files owned: none\nDone: verdict","status":"pending","owner":"","blockedBy":[]}
EOF
cat > "$axis_idle/4.json" <<'EOF'
{"id":"4","subject":"Task 2: review standards [reviewer]","description":"Files owned: none\nDone: verdict","status":"pending","owner":"","blockedBy":[]}
EOF
rev_idle='{"teammate_name":"reviewer-1","team_name":"t"}'
assert_stderr "an idle reviewer is offered the spec axis first (lowest id)" 2 'claim "Task 2: review spec \[reviewer\]"' \
    "$rev_idle" SUPERTEAM_TASKS_DIR="$axis_idle" SUPERTEAM_TEAMS_DIR="$teams_dir" -- "$IDLE_HOOK"
# with the spec seat taken, the same reviewer is offered the standards axis
cat > "$axis_idle/3.json" <<'EOF'
{"id":"3","subject":"Task 2: review spec [reviewer]","description":"Files owned: none\nDone: verdict","status":"completed","owner":"reviewer-1","blockedBy":[]}
EOF
# (cooldown 0: this checks task selection, not the per-teammate cooldown)
assert_stderr "with the spec axis done the reviewer is offered the standards axis" 2 'claim "Task 2: review standards \[reviewer\]"' \
    "$rev_idle" SUPERTEAM_TASKS_DIR="$axis_idle" SUPERTEAM_TEAMS_DIR="$teams_dir" SUPERTEAM_IDLE_COOLDOWN=0 -- "$IDLE_HOOK"

echo "Team hooks: task-brief: review axes and Standards line"

axis_repo="$TEST_ROOT/axis-repo"; mkdir -p "$axis_repo"
cat > "$axis_repo/CLAUDE.md" <<'EOF'
# Standards
EOF
cat > "$axis_repo/plan.md" <<'EOF'
# Plan

**Spec:** specs/fixture.md

### Task 2: Second thing

**Files owned:** `a.sh`
**Depends on:** Task 1
**Model tier:** most capable
**Isolation:** branch

- [ ] Step 1: do it.

## Global Constraints

- Zero dependencies.
EOF

spec_out="$(cd "$axis_repo" && "$BRIEF" --taskcreate plan.md 2 review-spec lane/x 2>&1 || true)"
std_out="$(cd "$axis_repo" && "$BRIEF" --taskcreate plan.md 2 review-standards lane/x 2>&1 || true)"
impl_out="$(cd "$axis_repo" && "$BRIEF" --taskcreate plan.md 2 implement lane/x 2>&1 || true)"

check_line() { # DESCRIPTION HAYSTACK LINE
    if printf '%s\n' "$2" | grep -qxF "$3"; then
        pass "$1"
    else
        fail "$1"
        printf '%s\n' "$2" | sed 's/^/      /'
    fi
}
check_line "review-spec subject names the spec axis" "$spec_out" "Subject: Task 2: review spec [reviewer]"
check_line "review-spec carries the spec rubric" "$spec_out" "Rubric: skills/superteam-driven-development/task-reviewer-prompt.md"
check_line "review-standards subject names the standards axis" "$std_out" "Subject: Task 2: review standards [reviewer]"
check_line "review-standards carries the standards rubric" "$std_out" "Rubric: skills/superteam-driven-development/task-standards-prompt.md"
check_line "review-standards carries the resolved Standards line" "$std_out" "Standards: CLAUDE.md"
check_line "implement carries the resolved Standards line" "$impl_out" "Standards: CLAUDE.md"
if printf '%s\n' "$impl_out" | grep -A1 '^Depends on:' | grep -qxF 'Standards: CLAUDE.md'; then
    pass "Standards sits right after Depends on"
else
    fail "Standards sits right after Depends on"
fi
if printf '%s\n' "$spec_out" | grep -q '^Standards:'; then
    fail "review-spec has no Standards line (spec axis does not read them)"
else
    pass "review-spec has no Standards line (spec axis does not read them)"
fi

no_std_repo="$TEST_ROOT/axis-repo-bare"; mkdir -p "$no_std_repo"
cp "$axis_repo/plan.md" "$no_std_repo/plan.md"
bare_out="$(cd "$no_std_repo" && "$BRIEF" --taskcreate plan.md 2 implement lane/x 2>&1 || true)"
check_line "no standards files resolves to 'Standards: none'" "$bare_out" "Standards: none"

review_rc=0
(cd "$axis_repo" && "$BRIEF" --taskcreate plan.md 2 review lane/x >/dev/null 2>&1) || review_rc=$?
if [ "$review_rc" -eq 3 ]; then
    pass "the retired 'review' kind exits 3"
else
    fail "the retired 'review' kind exits 3 (got $review_rc)"
fi

echo "Team hooks: hooks.json wiring"

if python3 -c "
import json, sys
with open('$HOOKS_JSON') as f:
    data = json.load(f)
hooks = data.get('hooks', {})
sys.exit(0 if all(k in hooks for k in ('TaskCreated', 'TeammateIdle', 'TaskCompleted')) else 1)
" 2>/dev/null; then
    pass "hooks.json is valid JSON and wires TaskCreated, TeammateIdle and TaskCompleted"
else
    fail "hooks.json is valid JSON and wires TaskCreated, TeammateIdle and TaskCompleted"
fi

if [[ "$FAILURES" -gt 0 ]]; then
    echo "STATUS: FAILED ($FAILURES failure(s))"
    exit 1
fi

echo "STATUS: PASSED"
