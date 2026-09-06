#!/usr/bin/env bash
# Tests for worktree-safe dispatch: a worktree implementer never receives an
# absolute path into the lead's checkout (the shared-checkout path into the
# gitignored .superteam/ workspace is refused by Claude Code's worktree
# guard) — briefs are inlined via `task-brief --print`, and reports are
# written relative to the IC's own cwd.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TDD_DIR="$REPO_ROOT/skills/team-driven-development"
TASK_BRIEF="$TDD_DIR/scripts/task-brief"

FAILURES=0
TEST_ROOT=""

pass() { echo "  [PASS] $1"; }
fail() {
    echo "  [FAIL] $1"
    FAILURES=$((FAILURES + 1))
}

cleanup() {
    if [[ -n "$TEST_ROOT" && -d "$TEST_ROOT" ]]; then
        rm -rf "$TEST_ROOT"
    fi
}

main() {
    echo "=== Test: dispatch-template ==="

    # (a) implementer-prompt.md tells the IC its paths are worktree-relative
    if grep -q "relative to your cwd" "$TDD_DIR/implementer-prompt.md"; then
        pass "implementer-prompt.md says paths are relative to your cwd"
    else
        fail "implementer-prompt.md says paths are relative to your cwd"
    fi

    # (b) no [BRIEF_FILE] placeholder and no literal absolute repo path
    #     anywhere an IC would read it (the rule text that explains the
    #     prohibition is allowed to say so — lines containing "never" are
    #     excluded)
    local f bad
    for f in "$TDD_DIR/implementer-prompt.md" "$TDD_DIR/re-review-prompt.md" "$TDD_DIR/SKILL.md"; do
        bad="$(grep -n '\[BRIEF_FILE\]' "$f" || true)"
        if [[ -n "$bad" ]]; then
            fail "$(basename "$f") contains no [BRIEF_FILE] placeholder"
            printf '%s\n' "$bad" | sed 's/^/    /'
        else
            pass "$(basename "$f") contains no [BRIEF_FILE] placeholder"
        fi

        bad="$(grep -n '/Users/\|<repo-root>/.superteam\|<repo>/.superteam' "$f" | grep -v 'never' || true)"
        if [[ -n "$bad" ]]; then
            fail "$(basename "$f") contains no literal absolute repo path"
            printf '%s\n' "$bad" | sed 's/^/    /'
        else
            pass "$(basename "$f") contains no literal absolute repo path"
        fi
    done

    # (c) task-brief --print prints the task text to stdout and creates no file
    TEST_ROOT="$(mktemp -d)"
    trap cleanup EXIT
    git init -q -b main "$TEST_ROOT/repo"
    local repo
    repo="$(cd "$TEST_ROOT/repo" && git rev-parse --show-toplevel)"
    cat > "$repo/plan.md" <<'PLAN'
# Plan

## Task 1: First thing

Do the first thing.
PLAN

    local out
    out="$(cd "$repo" && "$TASK_BRIEF" --print plan.md 1)"
    if [[ "$out" == *"Task 1: First thing"* && "$out" == *"Do the first thing."* ]]; then
        pass "task-brief --print prints the task text to stdout"
    else
        fail "task-brief --print prints the task text to stdout"
        echo "    got: $out"
    fi

    if [[ ! -e "$repo/.superteam" ]]; then
        pass "task-brief --print creates no .superteam workspace"
    else
        fail "task-brief --print creates no .superteam workspace"
    fi

    # (d) implementer-prompt.md mentions mkdir -p (report dir must be created)
    if grep -q "mkdir -p" "$TDD_DIR/implementer-prompt.md"; then
        pass "implementer-prompt.md mentions mkdir -p"
    else
        fail "implementer-prompt.md mentions mkdir -p"
    fi

    echo ""
    if [[ "$FAILURES" -ne 0 ]]; then
        echo "FAILED: $FAILURES assertion(s)."
        exit 1
    fi
    echo "PASS"
}

main "$@"
