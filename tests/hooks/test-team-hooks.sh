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

# assert_exit DESCRIPTION EXPECTED_EXIT STDIN_JSON [EXTRA_ENV...] -- HOOK [ARGS...]
assert_exit() {
    local description="$1" expected="$2" stdin_json="$3"
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
    local description="$1" expected="$2" pattern="$3" stdin_json="$4"; shift 4
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

idle_help_lines="$({ "$IDLE_HOOK" --help 2>/dev/null || true; } | wc -l | tr -d ' ')"
if [ "$idle_help_lines" -eq 5 ]; then
    pass "teammate-idle-claim --help prints 5 lines"
else
    fail "teammate-idle-claim --help prints 5 lines (got $idle_help_lines)"
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
