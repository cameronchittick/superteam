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

# json_escape STRING -- escape backslashes, double quotes and newlines for a
# JSON string value (a raw newline is not legal inside one)
json_escape() {
    printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' | \
        awk 'BEGIN { ORS = "" } NR > 1 { print "\\n" } { print }'
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

echo "Bash guard: the three denied commands"

assert_denied "tmux kill-server is denied" "tmux kill-server"
assert_denied "tmux kill-server mid-command is denied" "echo hi; tmux kill-server"
assert_denied "git checkout . is denied" "git checkout ."
assert_denied "git checkout -- . is denied" "git checkout -- ."
assert_denied "git reset --hard is denied" "git reset --hard"
assert_denied "git reset --hard origin/main is denied" "git reset --hard origin/main"

assert_allowed "rm -rf outside PWD is no longer the guard's business" "rm -rf ../other"

echo "Bash guard: neighbouring commands stay allowed"

assert_allowed "git checkout of a branch is allowed" "git checkout main"
assert_allowed "git reset --soft is allowed" "git reset --soft HEAD~1"
assert_allowed "tmux without kill-server is allowed" "tmux list-sessions"
assert_allowed "an ordinary command is allowed" "bash tests/hooks/test-team-hooks.sh"

echo "Bash guard: a forbidden command quoted in text is not a forbidden command"

# The three literal patterns match only in command position - at the start of
# the command or right after a separator. Writing about them is not running
# them; the final reviewer's report heredoc was denied three times for saying
# the words.
assert_allowed "echoing the words tmux kill-server is allowed" \
    'echo "never run tmux kill-server"'
assert_allowed "grepping for git reset --hard is allowed" \
    "grep 'git reset --hard' README.md"
assert_allowed "git checkout . inside a sentence is allowed" \
    'echo "we do not use git checkout . here"'
assert_allowed "a heredoc describing the guard is allowed" \
    'cat > notes.md <<EOF
The guard stops tmux kill-server and git reset --hard when you run them.
Delete the build dir with rm -rf ./build; keep /etc/hosts alone.
EOF'

# Command position still means denied, including after a separator.
assert_denied "git reset --hard after && is denied" "cd /tmp && git reset --hard"
assert_denied "tmux kill-server after a pipe is denied" "true | tmux kill-server"
assert_denied "sudo does not hide tmux kill-server" "sudo tmux kill-server"
assert_denied "a command on the second line of a script is denied" \
    'cd /tmp
git reset --hard'
assert_denied "\$( command substitution is command position" \
    'echo $(git reset --hard)'

# A backtick is NOT command position: backtick-quoted prose in a Markdown
# heredoc is how review reports are written, and a backtick-substituted
# destructive command is not the typo this guardrail exists for.
assert_allowed "a heredoc quoting commands in backticks is allowed" \
    'cat > report.md <<EOF
The guard denies `git reset --hard` and `tmux kill-server` in command position.
It no longer looks at `rm -rf` at all.
EOF'

echo "Bash guard: .. is a path segment, not a substring"

assert_allowed "a file name containing .. is allowed" "rm -rf ./my..dir"

echo "Bash guard: every deny names the escape hatch"

for deny_cmd in "tmux kill-server" "git checkout ." "git reset --hard"; do
    run_guard "$(payload "$deny_cmd")"
    if printf '%s' "$GUARD_OUT" | grep -q 'SUPERTEAM_SKIP_VERIFY_GATE=1 to bypass'; then
        pass "the deny for '$deny_cmd' names the escape hatch"
    else
        fail "the deny for '$deny_cmd' names the escape hatch"
        printf '%s\n' "$GUARD_OUT" | sed 's/^/      /'
    fi
done

echo "Bash guard: scope and bypass"

run_guard '{"tool_name":"Edit","tool_input":{"command":"git reset --hard"}}'
if [ "$GUARD_RC" -eq 0 ] && [ -z "$GUARD_OUT" ]; then
    pass "a non-Bash tool is not inspected"
else
    fail "a non-Bash tool is not inspected (exit $GUARD_RC)"
    printf '%s\n' "$GUARD_OUT" | sed 's/^/      /'
fi

assert_allowed "SUPERTEAM_SKIP_VERIFY_GATE=1 bypasses the guard" "git reset --hard" SUPERTEAM_SKIP_VERIFY_GATE=1

run_guard ''
if [ "$GUARD_RC" -eq 0 ] && [ -z "$GUARD_OUT" ]; then
    pass "empty stdin fails open"
else
    fail "empty stdin fails open (exit $GUARD_RC)"
fi

help_lines="$(bash "$GUARD" --help | wc -l | tr -d ' ')"
if [ "$help_lines" -eq 4 ]; then
    pass "bash-guard --help prints 4 lines"
else
    fail "bash-guard --help prints 4 lines (got $help_lines)"
fi

echo "Bash guard: the deny payload is always parseable JSON"

# A command carrying a double quote or backslashes used to be able to land
# unescaped in permissionDecisionReason through rm -rf's echoed-back target,
# so the deny emitted malformed JSON and Claude Code could not read the
# decision - the one input class where the guard failed open while believing
# it had denied. rm -rf no longer builds a reason from the command text, but
# the coverage is re-based on git reset --hard to keep guarding the JSON
# encoding itself against a future regression.
run_guard "$(payload 'git reset --hard /tmp/a"b/..')"
if printf '%s' "$GUARD_OUT" | python3 -c 'import json,sys; json.load(sys.stdin)' 2>/dev/null; then
    pass "a deny for a command with a double quote is valid JSON"
else
    fail "a deny for a command with a double quote is valid JSON"
    printf '%s\n' "$GUARD_OUT" | sed 's/^/      /'
fi

run_guard "$(payload 'git reset --hard /tmp/a\b\\c/..')"
if printf '%s' "$GUARD_OUT" | python3 -c 'import json,sys; json.load(sys.stdin)' 2>/dev/null; then
    pass "a deny for a command with backslashes is valid JSON"
else
    fail "a deny for a command with backslashes is valid JSON"
    printf '%s\n' "$GUARD_OUT" | sed 's/^/      /'
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
