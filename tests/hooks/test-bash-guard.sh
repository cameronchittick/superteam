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

echo "Bash guard: a forbidden command quoted in text is not a forbidden command"

# The four literal patterns match only in command position - at the start of
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
It also denies `rm -rf ../x`.
EOF'

echo "Bash guard: the rm walk stops at a glued separator"

# The parser used to reset only on a token that was exactly a separator, so
# "rm -rf ./x; cat /etc/hosts" left it mid-rm and tested every later token as
# a delete target - it denied naming the JSON tail.
assert_allowed "a separator glued to a target ends the rm clause" \
    "echo docs mention rm -rf ./x here; then later cat /etc/hosts"
assert_allowed "rm -rf inside the worktree then another command is allowed" \
    "rm -rf ./build; cat /etc/hosts"
assert_denied "a second rm after a separator is still checked" \
    "rm -rf ./build; rm -rf /etc/hosts"

# A separator with no space on either side glues to both neighbours, so the
# next token arrives with the separator in front of it.
assert_allowed "an unspaced ; ends the rm clause" \
    "rm -rf ./x;cat /etc/hosts"
assert_allowed "an unspaced && ends the rm clause" \
    "rm -rf ./x&&cat /etc/hosts"
assert_allowed "a separator glued to the next word ends the rm clause" \
    "rm -rf ./x |tee /etc/hosts"

# Separators are stripped before quotes, so a quoted target followed by a
# separator is still read as a target.
assert_denied "a quoted target with a trailing separator is checked" \
    'rm -rf "/etc/hosts"; echo done'

echo "Bash guard: .. is a path segment, not a substring"

assert_allowed "a file name containing .. is allowed" "rm -rf ./my..dir"
assert_allowed "a dotted file name is allowed" "rm -rf build/v1..2.log"
assert_denied "a leading ../ still escapes" "rm -rf ../x"

echo "Bash guard: every deny names the escape hatch"

for deny_cmd in "tmux kill-server" "git checkout ." "git reset --hard" "rm -rf ~/x"; do
    run_guard "$(payload "$deny_cmd")"
    if printf '%s' "$GUARD_OUT" | grep -q 'SUPERTEAM_SKIP_VERIFY_GATE=1 to bypass'; then
        pass "the deny for '$deny_cmd' names the escape hatch"
    else
        fail "the deny for '$deny_cmd' names the escape hatch"
        printf '%s\n' "$GUARD_OUT" | sed 's/^/      /'
    fi
done

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
if [ "$help_lines" -eq 5 ]; then
    pass "bash-guard --help prints 5 lines"
else
    fail "bash-guard --help prints 5 lines (got $help_lines)"
fi

echo "Bash guard: the deny payload is always parseable JSON"

# A target carrying a double quote used to land unescaped in
# permissionDecisionReason, so the deny emitted malformed JSON and Claude Code
# could not read the decision - the one input class where the guard failed open
# while believing it had denied.
run_guard "$(payload 'rm -rf /tmp/a"b/..')"
if printf '%s' "$GUARD_OUT" | python3 -c 'import json,sys; json.load(sys.stdin)' 2>/dev/null; then
    pass "a deny naming a path with a double quote is valid JSON"
else
    fail "a deny naming a path with a double quote is valid JSON"
    printf '%s\n' "$GUARD_OUT" | sed 's/^/      /'
fi

run_guard "$(payload 'rm -rf /tmp/a\b\\c/..')"
if printf '%s' "$GUARD_OUT" | python3 -c 'import json,sys; json.load(sys.stdin)' 2>/dev/null; then
    pass "a deny naming a path with backslashes is valid JSON"
else
    fail "a deny naming a path with backslashes is valid JSON"
    printf '%s\n' "$GUARD_OUT" | sed 's/^/      /'
fi

# Same exposure through $PWD, which is interpolated into the same string.
quoted_wt="$TEST_ROOT/we\"ird"
mkdir -p "$quoted_wt"
GUARD_RC=0
GUARD_OUT="$(cd "$quoted_wt" && printf '%s' "$(payload 'rm -rf ~/x')" | \
    env -i PATH="${PATH:-}" HOME="$TEST_ROOT/home" bash "$GUARD" 2>&1)" || GUARD_RC=$?
if printf '%s' "$GUARD_OUT" | python3 -c 'import json,sys; json.load(sys.stdin)' 2>/dev/null; then
    pass "a deny is valid JSON when the worktree path itself contains a quote"
else
    fail "a deny is valid JSON when the worktree path itself contains a quote"
    printf '%s\n' "$GUARD_OUT" | sed 's/^/      /'
fi

# The reason has to survive escaping intact, not just parse.
run_guard "$(payload 'rm -rf /tmp/a"b/..')"
if printf '%s' "$GUARD_OUT" | python3 -c '
import json, sys
reason = json.load(sys.stdin)["hookSpecificOutput"]["permissionDecisionReason"]
sys.exit(0 if "/tmp/a\"b/.." in reason else 1)
' 2>/dev/null; then
    pass "the deny reason still names the offending path verbatim"
else
    fail "the deny reason still names the offending path verbatim"
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
