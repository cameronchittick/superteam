#!/usr/bin/env bash
# Tests for hooks/task-monitor: the stuck-task monitor.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
MONITOR="$REPO_ROOT/hooks/task-monitor"
MONITORS_JSON="$REPO_ROOT/monitors/monitors.json"

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

# ts_ago MINUTES -> touch -t stamp for MINUTES ago (BSD date, then GNU date)
ts_ago() {
    date -v-"$1"M +%Y%m%d%H%M 2>/dev/null || date -d "$1 minutes ago" +%Y%m%d%H%M
}

# make_task DIR ID STATUS SUBJECT OWNER AGE_MINUTES
make_task() {
    local dir="$1" id="$2" status="$3" subject="$4" owner="$5" age="$6"
    mkdir -p "$dir"
    cat > "$dir/$id.json" <<EOF
{
  "id": "$id",
  "subject": "$subject",
  "description": "some work\nstatus: not this one",
  "owner": "$owner",
  "status": "$status",
  "blocks": [],
  "blockedBy": []
}
EOF
    touch -t "$(ts_ago "$age")" "$dir/$id.json"
}

# run_monitor DIR [EXTRA_ENV...] -- captures stdout+stderr, records exit code
MONITOR_OUT=""
MONITOR_RC=0
run_monitor() {
    local dir="$1"
    shift
    MONITOR_RC=0
    MONITOR_OUT="$(env -i PATH="${PATH:-}" HOME="$TEST_ROOT/home" ${1+"$@"} \
        bash "$MONITOR" "$dir" --once 2>&1)" || MONITOR_RC=$?
}

assert_contains() {
    local description="$1" needle="$2"
    if printf '%s' "$MONITOR_OUT" | grep -qF "$needle"; then
        pass "$description"
    else
        fail "$description (output did not contain: $needle)"
        printf '%s\n' "$MONITOR_OUT" | sed 's/^/      /'
    fi
}

assert_empty() {
    local description="$1"
    if [ -z "$MONITOR_OUT" ]; then
        pass "$description"
    else
        fail "$description (expected no output)"
        printf '%s\n' "$MONITOR_OUT" | sed 's/^/      /'
    fi
}

assert_rc() {
    local description="$1" expected="$2"
    if [ "$MONITOR_RC" -eq "$expected" ]; then
        pass "$description"
    else
        fail "$description (expected exit $expected, got $MONITOR_RC)"
    fi
}

mkdir -p "$TEST_ROOT/home"

echo "Task monitor: stuck detection"

stuck_dir="$TEST_ROOT/stuck"
make_task "$stuck_dir" 7 in_progress "Task 7: wire the gate [implementer]" impl-1 30

run_monitor "$stuck_dir"
assert_rc "a stuck task exits 0" 0
assert_contains "names the stuck task id" 'task 7'
assert_contains "names the stuck task subject" 'Task 7: wire the gate [implementer]'
assert_contains "names the owner" 'owner impl-1'
assert_contains "reports in_progress and an age in minutes" 'in_progress 30 min'

run_monitor "$stuck_dir"
assert_empty "the same stuck task is not emitted twice"

touch -t "$(ts_ago 25)" "$stuck_dir/7.json"
run_monitor "$stuck_dir"
assert_contains "re-emits once the task file is touched again" 'task 7'

echo "Task monitor: tasks that are not stuck"

pending_dir="$TEST_ROOT/pending"
make_task "$pending_dir" 8 pending "Task 8: not started [reviewer]" "" 30
run_monitor "$pending_dir"
assert_empty "an old pending task is not stuck"

fresh_dir="$TEST_ROOT/fresh"
make_task "$fresh_dir" 9 in_progress "Task 9: just claimed [implementer]" impl-2 1
run_monitor "$fresh_dir"
assert_empty "a freshly updated in_progress task is not stuck"

echo "Task monitor: SUPERTEAM_STUCK_MINUTES"

short_dir="$TEST_ROOT/short"
make_task "$short_dir" 3 in_progress "Task 3: two minutes old [implementer]" impl-3 2
run_monitor "$short_dir" SUPERTEAM_STUCK_MINUTES=1
assert_contains "SUPERTEAM_STUCK_MINUTES=1 makes a 2-minute-old task stuck" 'task 3'

echo "Task monitor: no task list"

MONITOR_RC=0
MONITOR_OUT="$(env -i PATH="${PATH:-}" HOME="$TEST_ROOT/home" bash "$MONITOR" --once 2>&1)" || MONITOR_RC=$?
assert_rc "no task list id and no DIR exits 0" 0
assert_empty "no task list id and no DIR prints nothing"

echo "Task monitor: owner fallback and --help"

noowner_dir="$TEST_ROOT/noowner"
make_task "$noowner_dir" 4 in_progress "Task 4: unclaimed [writer]" "" 30
run_monitor "$noowner_dir"
assert_contains "an unowned stuck task reports owner none" 'owner none'

help_lines="$(bash "$MONITOR" --help | wc -l | tr -d ' ')"
if [ "$help_lines" -ge 3 ]; then
    pass "task-monitor --help prints usage"
else
    fail "task-monitor --help prints usage (got $help_lines lines)"
fi

echo "Task monitor: monitors.json wiring"

if python3 -c "
import json, sys
with open('$MONITORS_JSON') as f:
    data = json.load(f)
names = [m.get('name') for m in data]
entry = [m for m in data if m.get('name') == 'stuck-tasks']
sys.exit(0 if entry and entry[0].get('command') and entry[0].get('description') else 1)
" 2>/dev/null; then
    pass "monitors.json is valid JSON with a stuck-tasks entry"
else
    fail "monitors.json is valid JSON with a stuck-tasks entry"
fi

if grep -q 'run-hook.cmd task-monitor' "$MONITORS_JSON" 2>/dev/null; then
    pass "monitors.json dispatches through run-hook.cmd"
else
    fail "monitors.json dispatches through run-hook.cmd"
fi

if [ "$FAILURES" -gt 0 ]; then
    echo "STATUS: FAILED ($FAILURES failure(s))"
    exit 1
fi

echo "STATUS: PASSED"
