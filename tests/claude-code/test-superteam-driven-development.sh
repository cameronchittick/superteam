#!/usr/bin/env bash
# Test: superteam-driven-development skill
# Verifies that the skill is loaded and follows correct workflow
#
# No drill coverage: this test asks the agent to *describe* SDD (string-
# matches its verbal explanation against expected keywords like
# "self-review", "skeptical", "worktree", "Step 1", "loop"). Drill scenarios
# test behavior (real subagent dispatch, plan-following, review loops),
# not description-recall. Kept by design.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

CLAUDE_PROMPT_TIMEOUT="${CLAUDE_PROMPT_TIMEOUT:-90}"

SKILL_DIR="$SCRIPT_DIR/../../skills/superteam-driven-development"

echo "=== Test: superteam-driven-development skill ==="
echo ""

# Test 0: static content checks (no `claude -p` calls — fast, no live agent)
echo "Test 0: Static content checks..."

if assert_contains "$(cat "$SKILL_DIR/SKILL.md")" "TaskCreate" "SKILL.md mentions TaskCreate"; then
    : # pass
else
    exit 1
fi

if assert_contains "$(cat "$SKILL_DIR/SKILL.md")" "addBlockedBy" "SKILL.md mentions addBlockedBy"; then
    : # pass
else
    exit 1
fi

if assert_contains "$(cat "$SKILL_DIR/SKILL.md")" "Task tools absent\|fallback" "SKILL.md states the fallback-ledger branch"; then
    : # pass
else
    exit 1
fi

if assert_contains "$(cat "$SKILL_DIR/implementer-prompt.md")" "Tests:" "implementer-prompt.md has a Tests: line"; then
    : # pass
else
    exit 1
fi

# The team-mode sections other skills point at, and the strings that carry
# the task graph, the pre-approval rule, teardown, and the lead's limits.
SKILL_TEXT="$(cat "$SKILL_DIR/SKILL.md")"
for s in "## Modes" "## Task graph" "## Role pool" "## Monitor loop" "## Restart" "## Fallback" "task-brief --taskcreate" "Task N: implement" "Task N: review" "Task N: merge" "settings.local.json" "shutdown_request" "never implements" "pending permission dialog" "Never spawn a haiku teammate" "Verified:" "### Task subjects" "continues the numbering" "no outcome words"; do
    if assert_contains "$SKILL_TEXT" "$s" "SKILL.md has $s"; then
        : # pass
    else
        exit 1
    fi
done

echo ""

# Test 1: Verify skill can be loaded
echo "Test 1: Skill loading..."

output=$(run_claude "What is the superteam-driven-development skill? Describe its key steps briefly." "$CLAUDE_PROMPT_TIMEOUT")

if assert_contains "$output" "superteam-driven-development\|Team-Driven Development\|Team Driven" "Skill is recognized"; then
    : # pass
else
    exit 1
fi

if assert_contains "$output" "Load Plan\|read.*plan\|extract.*tasks" "Mentions loading plan"; then
    : # pass
else
    exit 1
fi

echo ""

# Test 2: Verify skill describes correct workflow order
echo "Test 2: Workflow ordering..."

output=$(run_claude "In the superteam-driven-development skill, what comes first: spec compliance review or code quality review? Answer using exactly this structure:
First: <review type>
Second: <review type>" "$CLAUDE_PROMPT_TIMEOUT")

if assert_order "$output" "First:.*spec.*compliance" "Second:.*code.*quality" "Spec compliance before code quality"; then
    : # pass
else
    exit 1
fi

echo ""

# Test 3: Verify self-review is mentioned
echo "Test 3: Self-review requirement..."

output=$(run_claude "Does the superteam-driven-development skill require implementers to self-review before handoff, and can self-review replace the external reviews? Answer using exactly this structure:
Self-review required: <yes or no>
Self-review replaces external review: <yes or no>" "$CLAUDE_PROMPT_TIMEOUT")

if assert_contains "$output" "Self-review required:.*yes" "Mentions self-review"; then
    : # pass
else
    exit 1
fi

if assert_contains "$output" "Self-review replaces external review:.*no" "Self-review does not replace external review"; then
    : # pass
else
    exit 1
fi

echo ""

# Test 4: Verify plan is read once
echo "Test 4: Plan reading efficiency..."

output=$(run_claude "In superteam-driven-development, how many times should the controller read the plan file? When does this happen?" "$CLAUDE_PROMPT_TIMEOUT")

if assert_contains "$output" "once\|one time\|single" "Read plan once"; then
    : # pass
else
    exit 1
fi

if assert_contains "$output" "Step 1\|beginning\|start\|Load Plan" "Read at beginning"; then
    : # pass
else
    exit 1
fi

echo ""

# Test 5: Verify spec compliance reviewer is skeptical
echo "Test 5: Spec compliance reviewer mindset..."

output=$(run_claude "What is the spec compliance reviewer's attitude toward the implementer's report in superteam-driven-development?" "$CLAUDE_PROMPT_TIMEOUT")

if assert_contains "$output" "not.*trust\|don't trust\|skeptical\|verify.*independently\|suspiciously" "Reviewer is skeptical"; then
    : # pass
else
    exit 1
fi

if assert_contains "$output" "read.*code\|inspect.*code\|verify.*code\|read.*diff\|trust.*diff" "Reviewer reads code"; then
    : # pass
else
    exit 1
fi

echo ""

# Test 6: Verify review loops
echo "Test 6: Review loop requirements..."

output=$(run_claude "In superteam-driven-development, what happens if a reviewer finds issues? Is it a one-time review or a loop?" "$CLAUDE_PROMPT_TIMEOUT")

if assert_contains "$output" "loop\|again\|repeat\|until.*approved\|until.*compliant" "Review loops mentioned"; then
    : # pass
else
    exit 1
fi

if assert_contains "$output" "implementer.*fix\|fix.*issues" "Implementer fixes issues"; then
    : # pass
else
    exit 1
fi

echo ""

# Test 7: Verify full task text is provided
echo "Test 7: Task context provision..."

output=$(run_claude "In superteam-driven-development, how does the controller provide task information to the implementer subagent? Answer using exactly this structure:
Controller provides: <directly or by file>
Implementer must read plan file: <yes or no>" "$CLAUDE_PROMPT_TIMEOUT")

if assert_contains "$output" "provide.*directly\|full.*text\|paste\|include.*prompt" "Provides text directly"; then
    : # pass
else
    exit 1
fi

if assert_contains "$output" "Implementer must read plan file:.*no" "Doesn't make subagent read file"; then
    : # pass
else
    exit 1
fi

echo ""

# Test 8: Verify worktree requirement
echo "Test 8: Worktree requirement..."

output=$(run_claude "What workflow skills are required before using superteam-driven-development? List any prerequisites or required skills." "$CLAUDE_PROMPT_TIMEOUT")

if assert_contains "$output" "using-git-worktrees\|worktree" "Mentions worktree requirement"; then
    : # pass
else
    exit 1
fi

echo ""

# Test 9: Verify main branch warning
echo "Test 9: Main branch red flag..."

output=$(run_claude "In superteam-driven-development, is it okay to start implementation directly on the main branch?" "$CLAUDE_PROMPT_TIMEOUT")

if assert_contains "$output" "worktree\|feature.*branch\|not.*main\|never.*main\|avoid.*main\|don't.*main\|consent\|permission" "Warns against main branch"; then
    : # pass
else
    exit 1
fi

echo ""

echo "=== All superteam-driven-development skill tests passed ==="
