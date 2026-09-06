#!/usr/bin/env bash
# Tests for hooks/bash-guard: the PreToolUse Bash deny list.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
GUARD="$REPO_ROOT/hooks/bash-guard"
HOOKS_JSON="$REPO_ROOT/hooks/hooks.json"

FAILURES=0
# pwd -P: on macOS mktemp -d hands back /var/... which is a symlink to
# /private/var/..., and the guard compares $PWD literally.
TEST_ROOT="$(cd "$(mktemp -d)" && pwd -P)"
WT="$TEST_ROOT/worktree"
mkdir -p "$WT"

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

# json_escape STRING -- escape backslashes and double quotes for a JSON string
json_escape() {
    printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}

# payload COMMAND -- a PreToolUse Bash payload carrying COMMAND
payload() {
    printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$(json_escape "$1")"
}

# run_guard STDIN_JSON [EXTRA_ENV...] -- runs the guard with cwd = $WT, so the
# hook's $PWD is the pretend worktree. bash sets PWD from getcwd(), so cwd is
# the only way to tell the hook where the worktree is.
GUARD_OUT=""
GUARD_RC=0
run_guard() {
    local stdin_json="$1"
    shift
    GUARD_RC=0
    GUARD_OUT="$(cd "$WT" && printf '%s' "$stdin_json" | \
        env -i PATH="${PATH:-}" HOME="$TEST_ROOT/home" ${1+"$@"} bash "$GUARD" 2>&1)" || GUARD_RC=$?
}

assert_denied() {
    local description="$1" command="$2"
    run_guard "$(payload "$command")"
    if [ "$GUARD_RC" -ne 0 ]; then
        fail "$description (guard exited $GUARD_RC, expected 0 with a deny payload)"
        printf '%s\n' "$GUARD_OUT" | sed 's/^/      /'
        return
    fi
    if printf '%s' "$GUARD_OUT" | grep -q '"permissionDecision": "deny"' &&
       printf '%s' "$GUARD_OUT" | grep -q '"hookEventName": "PreToolUse"'; then
        pass "$description"
    else
        fail "$description (expected a PreToolUse deny payload)"
        printf '%s\n' "$GUARD_OUT" | sed 's/^/      /'
    fi
}

assert_allowed() {
    local description="$1" command="$2"
    shift 2
    run_guard "$(payload "$command")" ${1+"$@"}
    if [ "$GUARD_RC" -eq 0 ] && [ -z "$GUARD_OUT" ]; then
        pass "$description"
    else
        fail "$description (expected exit 0 and no output, got exit $GUARD_RC)"
        printf '%s\n' "$GUARD_OUT" | sed 's/^/      /'
    fi
}

mkdir -p "$TEST_ROOT/home"

echo "Bash guard: the four denied commands"

assert_denied "tmux kill-server is denied" "tmux kill-server"
assert_denied "tmux kill-server mid-command is denied" "echo hi; tmux kill-server"
assert_denied "git checkout . is denied" "git checkout ."
assert_denied "git checkout -- . is denied" "git checkout -- ."
assert_denied "git reset --hard is denied" "git reset --hard"
assert_denied "git reset --hard origin/main is denied" "git reset --hard origin/main"

echo "Bash guard: rm -rf outside the worktree"

assert_denied "rm -rf on a parent-relative path is denied" "rm -rf ../other"
assert_denied "rm -rf on a home path is denied" "rm -rf ~/x"
assert_denied "rm -rf on an absolute path outside PWD is denied" "rm -rf /tmp/somewhere-else"
assert_denied "rm -fr is spelled the other way round and still denied" "rm -fr ../other"
assert_denied "rm -r -f split flags are denied" "rm -r -f ../other"
assert_denied "a path escaping through .. mid-string is denied" "rm -rf ./build/../../other"

echo "Bash guard: rm -rf inside the worktree is allowed"

assert_allowed "rm -rf on a relative path is allowed" "rm -rf ./build"
assert_allowed "rm -rf on a bare relative path is allowed" "rm -rf build/cache"
assert_allowed "rm -rf under the real PWD is allowed" "rm -rf \"$WT/tmp\""
assert_allowed "rm -rf on an unexpanded \$PWD path is allowed" 'rm -rf "$PWD/tmp"'
assert_allowed "rm without -r or -f is allowed" "rm ../other/file.txt"

echo "Bash guard: neighbouring commands stay allowed"

assert_allowed "git checkout of a branch is allowed" "git checkout main"
assert_allowed "git reset --soft is allowed" "git reset --soft HEAD~1"
assert_allowed "tmux without kill-server is allowed" "tmux list-sessions"
assert_allowed "an ordinary command is allowed" "bash tests/hooks/test-team-hooks.sh"

echo "Bash guard: scope and bypass"

run_guard '{"tool_name":"Edit","tool_input":{"command":"rm -rf ~/x"}}'
if [ "$GUARD_RC" -eq 0 ] && [ -z "$GUARD_OUT" ]; then
    pass "a non-Bash tool is not inspected"
else
    fail "a non-Bash tool is not inspected (exit $GUARD_RC)"
    printf '%s\n' "$GUARD_OUT" | sed 's/^/      /'
fi

assert_allowed "SUPERTEAM_SKIP_VERIFY_GATE=1 bypasses the guard" "rm -rf ~/x" SUPERTEAM_SKIP_VERIFY_GATE=1

run_guard ''
if [ "$GUARD_RC" -eq 0 ] && [ -z "$GUARD_OUT" ]; then
    pass "empty stdin fails open"
else
    fail "empty stdin fails open (exit $GUARD_RC)"
fi

help_lines="$(bash "$GUARD" --help | wc -l | tr -d ' ')"
if [ "$help_lines" -ge 5 ]; then
    pass "bash-guard --help prints usage"
else
    fail "bash-guard --help prints usage (got $help_lines lines, expected at least 5)"
fi

echo "Bash guard: hooks.json wiring"

if python3 -c "
import json, sys
with open('$HOOKS_JSON') as f:
    data = json.load(f)
entries = data.get('hooks', {}).get('PreToolUse', [])
ok = any(
    e.get('matcher') == 'Bash' and
    any('bash-guard' in h.get('command', '') for h in e.get('hooks', []))
    for e in entries
)
sys.exit(0 if ok else 1)
" 2>/dev/null; then
    pass "hooks.json wires PreToolUse with matcher Bash to bash-guard"
else
    fail "hooks.json wires PreToolUse with matcher Bash to bash-guard"
fi

if python3 -c "
import json, sys
with open('$HOOKS_JSON') as f:
    hooks = json.load(f).get('hooks', {})
sys.exit(0 if all(k in hooks for k in ('SessionStart', 'TaskCreated', 'TeammateIdle', 'TaskCompleted')) else 1)
" 2>/dev/null; then
    pass "hooks.json keeps the existing SessionStart and team hooks"
else
    fail "hooks.json keeps the existing SessionStart and team hooks"
fi

if [ "$FAILURES" -gt 0 ]; then
    echo "STATUS: FAILED ($FAILURES failure(s))"
    exit 1
fi

echo "STATUS: PASSED"
