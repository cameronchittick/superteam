#!/usr/bin/env bash
# Static tests for the isolation-tier rule text: docs/isolation-tiers.md
# carries the required sections and table rows, and the skills/README/agent
# files that state or point at the rule say what the plan requires. Task-brief
# behaviour, the agents' branch-tier line and the guard's arms are asserted by
# the tests Tasks 2-4 own; this suite covers only the rule text itself.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DOC="$REPO_ROOT/docs/isolation-tiers.md"
SDD_SKILL="$REPO_ROOT/skills/superteam-driven-development/SKILL.md"
PLAN_SKILL="$REPO_ROOT/skills/writing-plans/SKILL.md"
README="$REPO_ROOT/README.md"
EXEC_SKILL="$REPO_ROOT/skills/executing-plans/SKILL.md"
REVIEWER="$REPO_ROOT/agents/reviewer.md"

FAILURES=0
pass() { echo "  [PASS] $1"; }
fail() {
    echo "  [FAIL] $1"
    FAILURES=$((FAILURES + 1))
}

main() {
    echo "=== Test: isolation-tiers ==="

    # (a) docs/isolation-tiers.md exists
    if [[ -f "$DOC" ]]; then
        pass "docs/isolation-tiers.md exists"
    else
        fail "docs/isolation-tiers.md exists"
        echo ""
        echo "FAILED: $FAILURES assertion(s)."
        exit 1
    fi

    # (b) required section headings, and the retired heading is gone
    local heading
    for heading in '^## The tiers' '^## Escalation and what the ledger records' \
        '^## Sizing the work' '^## The solo flow' '^## The branch-tier flow'; do
        if grep -qE "$heading" "$DOC"; then
            pass "docs/isolation-tiers.md has heading: $heading"
        else
            fail "docs/isolation-tiers.md has heading: $heading"
        fi
    done
    if grep -qi 'one-task flow' "$DOC"; then
        fail "docs/isolation-tiers.md does not have a 'one-task flow' heading"
    else
        pass "docs/isolation-tiers.md does not have a 'one-task flow' heading"
    fi

    # (c) the tier table's four row labels
    local row
    for row in '| **solo** |' '| **branch** (default) |' '| **worktree** |' '| **provisioned** |'; do
        if grep -qF "$row" "$DOC"; then
            pass "docs/isolation-tiers.md table has row: $row"
        else
            fail "docs/isolation-tiers.md table has row: $row"
        fi
    done

    # (d) SDD skill: Isolation tiers heading and the two required phrases
    if grep -qE '^## Isolation tiers' "$SDD_SKILL"; then
        pass "SDD SKILL.md has heading: ## Isolation tiers"
    else
        fail "SDD SKILL.md has heading: ## Isolation tiers"
    fi
    if tr '\n' ' ' <"$SDD_SKILL" | grep -qF 'two or more writing tasks are unblocked at the same time'; then
        pass "SDD SKILL.md states the escalation trigger"
    else
        fail "SDD SKILL.md states the escalation trigger"
    fi
    if grep -qF 'never a category the brief matches' "$SDD_SKILL"; then
        pass "SDD SKILL.md states the sizing is a scale, not a category"
    else
        fail "SDD SKILL.md states the sizing is a scale, not a category"
    fi

    # the retired gate wording is gone from both rule texts
    local rule_file
    for rule_file in "$DOC" "$SDD_SKILL"; do
        if grep -qF 'do not run by default' "$rule_file"; then
            fail "$(basename "$rule_file") no longer says: do not run by default"
        else
            pass "$(basename "$rule_file") no longer says: do not run by default"
        fi
    done

    # (e) writing-plans skill: skeptic trigger phrase and Isolation header line
    if grep -qF 'Sizing the work' "$PLAN_SKILL"; then
        pass "writing-plans SKILL.md has: Sizing the work"
    else
        fail "writing-plans SKILL.md has: Sizing the work"
    fi
    if grep -qE '^\*\*Isolation:\*\* solo \| branch \| worktree \| provisioned$' "$PLAN_SKILL"; then
        pass "writing-plans SKILL.md has the Isolation header-line template"
    else
        fail "writing-plans SKILL.md has the Isolation header-line template"
    fi

    # (f) README and executing-plans skill each point at the rule page
    local f
    for f in "$README" "$EXEC_SKILL"; do
        if grep -qF 'isolation-tiers' "$f"; then
            pass "$(basename "$f") mentions isolation-tiers"
        else
            fail "$(basename "$f") mentions isolation-tiers"
        fi
    done

    # (g) reviewer agent: diffs commits, never the working tree
    if grep -qF 'never the working tree' "$REVIEWER"; then
        pass "agents/reviewer.md contains: never the working tree"
    else
        fail "agents/reviewer.md contains: never the working tree"
    fi

    echo ""
    if [[ "$FAILURES" -ne 0 ]]; then
        echo "FAILED: $FAILURES assertion(s)."
        exit 1
    fi
    echo "PASS"
}

main "$@"
