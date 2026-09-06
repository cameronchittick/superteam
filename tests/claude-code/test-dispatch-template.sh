#!/usr/bin/env bash
# Tests for worktree-safe dispatch: a worktree implementer never receives an
# absolute path into the lead's checkout (the shared-checkout path into the
# gitignored .superteam/ workspace is refused by Claude Code's worktree
# guard) — briefs are inlined via `task-brief --print`, and reports are
# written relative to the IC's own cwd.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TDD_DIR="$REPO_ROOT/skills/superteam-driven-development"
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

**Spec:** `docs/spec.md`

## Global Constraints
- Keep it simple.

## Task 1: First thing

**Files owned:** `src/a.py`, `src/b.py`
**Depends on:** none
**Model tier:** standard

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

    # (c2) task-brief --taskcreate emits a TaskCreate subject line and body
    local tc tr tm line
    tc="$(cd "$repo" && "$TASK_BRIEF" --taskcreate plan.md 1 implement lane/x)"
    if printf '%s\n' "$tc" | sed -n 1p | grep -q '^Subject: Task 1: implement \[implementer\]$'; then pass "--taskcreate implement subject carries role tag"; else fail "--taskcreate implement subject carries role tag"; fi
    for line in '^Lane: lane/x$' '^Worktree: task-1-impl' '^Files owned: ' '^Done: report at \.superteam/sdd/' '^## Task Brief$' '^## Global Constraints$'; do
        if printf '%s\n' "$tc" | grep -q "$line"; then pass "--taskcreate body has $line"; else fail "--taskcreate body has $line"; fi
    done
    if printf '%s\n' "$tc" | grep -q '^Files owned: src/a.py, src/b.py$'; then pass "--taskcreate copies Files owned without backticks"; else fail "--taskcreate copies Files owned without backticks"; fi
    if printf '%s\n' "$tc" | grep -q '^Plan: plan.md   Spec: docs/spec.md$'; then pass "--taskcreate body has the Plan/Spec line"; else fail "--taskcreate body has the Plan/Spec line"; fi
    if printf '%s\n' "$tc" | grep -qE '^(Role|Model):'; then fail "--taskcreate body has no Role:/Model: line"; else pass "--taskcreate body has no Role:/Model: line"; fi
    tr="$(cd "$repo" && "$TASK_BRIEF" --taskcreate plan.md 1 review lane/x)"
    if printf '%s\n' "$tr" | grep -q '^Subject: Task 1: review \[reviewer\]$' && printf '%s\n' "$tr" | grep -q '^Reviews: worktree-task-1-impl$'; then pass "--taskcreate review subject and Reviews: line"; else fail "--taskcreate review subject and Reviews: line"; fi
    tm="$(cd "$repo" && "$TASK_BRIEF" --taskcreate plan.md 1 merge lane/x)"
    if printf '%s\n' "$tm" | grep -q '^Subject: Task 1: merge \[integrator\]$' && printf '%s\n' "$tm" | grep -q '^Merge: worktree-task-1-impl → lane/x$'; then pass "--taskcreate merge subject and Merge: line"; else fail "--taskcreate merge subject and Merge: line"; fi
    if (cd "$repo" && "$TASK_BRIEF" --taskcreate plan.md 1 bogus lane/x) >/dev/null 2>&1; then fail "--taskcreate rejects unknown kind"; else pass "--taskcreate rejects unknown kind"; fi
    if (cd "$repo" && "$TASK_BRIEF" --taskcreate plan.md 9 implement lane/x) >/dev/null 2>&1; then fail "--taskcreate rejects a missing task number"; else pass "--taskcreate rejects a missing task number"; fi

    # (c3) a prose task's Model tier makes the implement role [writer]
    cat > "$repo/prose-plan.md" <<'PLAN'
# Plan

## Global Constraints
- Prose only.

## Task 1: Write the docs

**Files owned:** `README.md`
**Depends on:** none
**Model tier:** prose

Write it.
PLAN
    local tw
    tw="$(cd "$repo" && "$TASK_BRIEF" --taskcreate prose-plan.md 1 implement lane/x)"
    if printf '%s\n' "$tw" | grep -q '^Subject: Task 1: implement \[writer\]$'; then pass "--taskcreate prose Model tier gives the [writer] role"; else fail "--taskcreate prose Model tier gives the [writer] role"; fi
    if printf '%s\n' "$tw" | grep -q '^Plan: prose-plan.md   Spec: none$'; then pass "--taskcreate Spec falls back to none"; else fail "--taskcreate Spec falls back to none"; fi

    # (c4) a task block ends at the next heading of the same or higher level,
    #      whatever its text — the last task must not swallow a trailing
    #      "## Finish" section
    cat > "$repo/finish-plan.md" <<'PLAN'
# Plan

## Global Constraints
- Keep it simple.

## Task 1: First thing

**Files owned:** `src/a.py`
**Depends on:** none
**Model tier:** standard

Do the first thing.

## Task 2: Last thing

**Files owned:** `src/b.py`
**Depends on:** none
**Model tier:** standard

Do the last thing.

## Finish (lead)

MERGE-THE-LANE-AND-BUMP-MANIFESTS
PLAN
    local last tc_last
    last="$(cd "$repo" && "$TASK_BRIEF" --print finish-plan.md 2)"
    if [[ "$last" == *"Do the last thing."* && "$last" != *"MERGE-THE-LANE-AND-BUMP-MANIFESTS"* ]]; then
        pass "--print stops the last task at the next same-level heading"
    else
        fail "--print stops the last task at the next same-level heading"
        echo "    got: $last"
    fi
    tc_last="$(cd "$repo" && "$TASK_BRIEF" --taskcreate finish-plan.md 2 implement lane/x)"
    if [[ "$tc_last" != *"MERGE-THE-LANE-AND-BUMP-MANIFESTS"* ]]; then
        pass "--taskcreate brief stops at the next same-level heading"
    else
        fail "--taskcreate brief stops at the next same-level heading"
    fi
    if [[ "$last" != *"Do the first thing."* ]]; then
        pass "--print does not leak the previous task"
    else
        fail "--print does not leak the previous task"
    fi

    # (d) implementer-prompt.md mentions mkdir -p (report dir must be created)
    if grep -q "mkdir -p" "$TDD_DIR/implementer-prompt.md"; then
        pass "implementer-prompt.md mentions mkdir -p"
    else
        fail "implementer-prompt.md mentions mkdir -p"
    fi

    # (e) TDD is always on in implementer-prompt.md: no conditional
    #     qualifier survives, and the skill is named with its prefix
    local prompt="$TDD_DIR/implementer-prompt.md" qualifier hits
    hits=""
    for qualifier in "if task says to" "if required" "if TDD was required"; do
        hits+="$(grep -nF "$qualifier" "$prompt" || true)"
    done
    if [[ -z "$hits" ]]; then
        pass "implementer-prompt.md makes TDD unconditional"
    else
        fail "implementer-prompt.md makes TDD unconditional"
        printf '%s\n' "$hits" | sed 's/^/    /'
    fi

    if grep -q 'superteam:test-driven-development' "$prompt"; then
        pass "implementer-prompt.md names superteam:test-driven-development"
    else
        fail "implementer-prompt.md names superteam:test-driven-development"
    fi

    # (f) the same cadence as implementer.md: Standards read first, focused
    #     file while iterating, full suite once before the commit
    if grep -q '`Standards:`' "$prompt" && grep -q 'before writing' "$prompt"; then
        pass "implementer-prompt.md reads the Standards: files before writing"
    else
        fail "implementer-prompt.md reads the Standards: files before writing"
    fi

    if grep -q 'focused test' "$prompt" && grep -q 'full suite once' "$prompt"; then
        pass "implementer-prompt.md runs the focused file, then the full suite once"
    else
        fail "implementer-prompt.md runs the focused file, then the full suite once"
    fi

    echo ""
    if [[ "$FAILURES" -ne 0 ]]; then
        echo "FAILED: $FAILURES assertion(s)."
        exit 1
    fi
    echo "PASS"
}

main "$@"
