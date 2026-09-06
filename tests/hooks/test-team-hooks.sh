#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
VERIFY_HOOK="$REPO_ROOT/hooks/task-completed-verify"
IDLE_HOOK="$REPO_ROOT/hooks/teammate-idle-claim"

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
    output="$(printf '%s' "$stdin_json" | env -i PATH="${PATH:-}" "${env_args[@]}" "$@" 2>&1)" || actual=$?

    if [ "$actual" -eq "$expected" ]; then
        pass "$description"
    else
        fail "$description (expected exit $expected, got $actual)"
        echo "$output" | sed 's/^/      /'
    fi
}

echo "Team hooks: task-completed-verify"

assert_exit \
    "description with Verified: line allows completion" \
    0 \
    '{"task_id":"4","task_subject":"x","task_description":"did stuff\nVerified: ran tests, all pass"}' \
    -- "$VERIFY_HOOK"

assert_exit \
    "description with no evidence blocks completion" \
    2 \
    '{"task_id":"4","task_subject":"x","task_description":"no evidence here"}' \
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
    "$(printf '{"task_id":"4","task_subject":"x","task_description":"no evidence","cwd":"%s"}' "$report_home")" \
    -- "$VERIFY_HOOK"

assert_exit \
    "SUPERTEAM_SKIP_VERIFY_GATE=1 bypasses the gate" \
    0 \
    '{"task_id":"4","task_subject":"x","task_description":"no evidence"}' \
    SUPERTEAM_SKIP_VERIFY_GATE=1 \
    -- "$VERIFY_HOOK"

assert_exit \
    "malformed JSON exits 0 (fail open, never crashes)" \
    0 \
    'not json at all {{{' \
    -- "$VERIFY_HOOK"

help_output="$("$VERIFY_HOOK" --help)"
help_lines="$(printf '%s\n' "$help_output" | wc -l | tr -d ' ')"
if [ "$help_lines" -eq 5 ]; then
    pass "task-completed-verify --help prints 5 lines"
else
    fail "task-completed-verify --help prints 5 lines (got $help_lines)"
fi

echo "Team hooks: teammate-idle-claim"

idle_home="$TEST_ROOT/idle-home"
mkdir -p "$idle_home/.claude/tasks/session-testteam"
cat > "$idle_home/.claude/tasks/session-testteam/1.json" <<'EOF'
{
  "id": "1",
  "subject": "Do thing",
  "status": "pending",
  "blocks": [],
  "blockedBy": []
}
EOF

assert_exit \
    "idle with an unowned pending unblocked task blocks going idle" \
    2 \
    '{"teammate_name":"researcher","team_name":"session-testteam"}' \
    HOME="$idle_home" \
    -- "$IDLE_HOOK"

cat > "$idle_home/.claude/tasks/session-testteam/1.json" <<'EOF'
{
  "id": "1",
  "subject": "Do thing",
  "status": "pending",
  "blocks": [],
  "blockedBy": [],
  "owner": "researcher"
}
EOF

assert_exit \
    "idle with all tasks owned allows going idle" \
    0 \
    '{"teammate_name":"researcher","team_name":"session-testteam"}' \
    HOME="$idle_home" \
    -- "$IDLE_HOOK"

assert_exit \
    "idle fails open when teammate_name is absent" \
    0 \
    '{"team_name":"session-testteam"}' \
    HOME="$idle_home" \
    -- "$IDLE_HOOK"

idle_help_output="$("$IDLE_HOOK" --help)"
idle_help_lines="$(printf '%s\n' "$idle_help_output" | wc -l | tr -d ' ')"
if [ "$idle_help_lines" -eq 5 ]; then
    pass "teammate-idle-claim --help prints 5 lines"
else
    fail "teammate-idle-claim --help prints 5 lines (got $idle_help_lines)"
fi

if [[ "$FAILURES" -gt 0 ]]; then
    echo "STATUS: FAILED ($FAILURES failure(s))"
    exit 1
fi

echo "STATUS: PASSED"
