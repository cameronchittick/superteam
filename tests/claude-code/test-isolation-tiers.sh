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
        '^## Sizing the work' '^## The trunk flow' '^## The branch-tier flow'; do
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
    for row in '| **trunk** (default) |' '| **branch** |' '| **worktree** |' '| **provisioned** |'; do
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

    # (d2) both rule texts say the lead does not implement and that a
    #      human-direct request is sized like any other brief; the retired
    #      own-hands size and solo tier are gone from both
    local phrase
    for rule_file in "$DOC" "$SDD_SKILL"; do
        for phrase in 'the lead does not implement' 'sized and delegated exactly like a brief from above'; do
            if tr '\n' ' ' <"$rule_file" | grep -qF "$phrase"; then
                pass "$(basename "$rule_file") states: $phrase"
            else
                fail "$(basename "$rule_file") states: $phrase"
            fi
        done
        for phrase in 'Own hands' '| **solo** |'; do
            if grep -qF "$phrase" "$rule_file"; then
                fail "$(basename "$rule_file") no longer contains: $phrase"
            else
                pass "$(basename "$rule_file") no longer contains: $phrase"
            fi
        done
    done

    # (d3) both rule texts carry the trunk-tier rule, and the retired
    #      branch-as-default label is gone from both
    for rule_file in "$DOC" "$SDD_SKILL"; do
        for phrase in 'a merge commit for nothing' 'no review seat'; do
            if tr '\n' ' ' <"$rule_file" | grep -qF "$phrase"; then
                pass "$(basename "$rule_file") states: $phrase"
            else
                fail "$(basename "$rule_file") states: $phrase"
            fi
        done
        if grep -qF '**branch** (default)' "$rule_file"; then
            fail "$(basename "$rule_file") no longer contains: **branch** (default)"
        else
            pass "$(basename "$rule_file") no longer contains: **branch** (default)"
        fi
    done

    # (d4) both rule texts state the second-seat gate: its three steps in
    #      order, and that the split goes to both seats
    for rule_file in "$DOC" "$SDD_SKILL"; do
        for phrase in 'is a gate of three steps, in order' \
            'set to worktree before anything else' \
            'sent to both seats' \
            'acknowledges the split by message' \
            'waits for the acknowledgement rather than assuming delivery' \
            'true to what it knew and false to what the lead knows'; do
            if tr '\n' ' ' <"$rule_file" | tr -s ' ' | grep -qF "$phrase"; then
                pass "$(basename "$rule_file") states the second-seat gate: $phrase"
            else
                fail "$(basename "$rule_file") states the second-seat gate: $phrase"
            fi
        done
    done

    # (d5) SDD skill states the spawn-directory check and the stalled-seat
    #      check, and the worktree tier definition still stands
    for phrase in 'never anywhere under `~/.claude`' \
        'git rev-parse --show-toplevel' \
        'return to the repo root before spawning' \
        'workspace trust dialog' \
        'tmux capture-pane -p -t <pane>' \
        'kill the seat and respawn from the repo root, never answer the dialog' \
        '**worktree**: two or more writing seats must write in this repo at once'; do
        if tr '\n' ' ' <"$SDD_SKILL" | tr -s ' ' | grep -qF "$phrase"; then
            pass "SDD SKILL.md states: $phrase"
        else
            fail "SDD SKILL.md states: $phrase"
        fi
    done

    # (e) writing-plans skill: skeptic trigger phrase and Isolation header line
    if grep -qF 'Sizing the work' "$PLAN_SKILL"; then
        pass "writing-plans SKILL.md has: Sizing the work"
    else
        fail "writing-plans SKILL.md has: Sizing the work"
    fi
    if grep -qE '^\*\*Isolation:\*\* trunk \| branch \| worktree \| provisioned$' "$PLAN_SKILL"; then
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
