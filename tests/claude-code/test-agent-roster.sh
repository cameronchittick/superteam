#!/usr/bin/env bash
# Static tests for the six-agent roster in agents/: every agent exists with
# its name, no agent inherits its model, every dispatch site in skills/ names
# a roster agent, and the retired superteam:ic name is gone.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
AGENTS="$REPO_ROOT/agents"
SKILLS="$REPO_ROOT/skills"
ROSTER=(implementer researcher reviewer skeptic writer integrator)

FAILURES=0
pass() { echo "  [PASS] $1"; }
fail() {
    echo "  [FAIL] $1"
    FAILURES=$((FAILURES + 1))
}

main() {
    echo "=== Test: agent-roster ==="

    # (a) each roster agent exists and declares its own name
    for role in "${ROSTER[@]}"; do
        if [[ -f "$AGENTS/$role.md" ]] && grep -q "^name: $role$" "$AGENTS/$role.md"; then
            pass "agents/$role.md exists with name: $role"
        else
            fail "agents/$role.md exists with name: $role"
        fi
    done

    # (b) no agent inherits its model
    local inherit
    inherit="$(grep -ln "^model: inherit" "$AGENTS"/*.md 2>/dev/null || true)"
    if [[ -z "$inherit" ]]; then
        pass "no agent file says model: inherit"
    else
        fail "no agent file says model: inherit"
        echo "    found in: $inherit"
    fi

    # (c) every subagent_type in skills/ is superteam:<role> with a matching
    #     agent file, except the other-harness fallback comment
    #     ("general-purpose if ...")
    local bad=0 line value role
    while IFS= read -r line; do
        [[ "$line" == *"general-purpose if"* ]] && continue
        value="$(printf '%s' "$line" | grep -o 'subagent_type: *"[^"]*"' | sed 's/.*"\(.*\)"/\1/')"
        role="${value#superteam:}"
        if [[ "$value" != superteam:* || ! -f "$AGENTS/$role.md" ]]; then
            echo "    $line"
            bad=$((bad + 1))
        fi
    done < <(grep -rn 'subagent_type: *"[^"]*"' "$SKILLS")
    if [[ "$bad" -eq 0 ]]; then
        pass "every subagent_type in skills/ names a roster agent"
    else
        fail "every subagent_type in skills/ names a roster agent ($bad offending line(s))"
    fi

    # (d) the retired superteam:ic name is gone
    local ic
    ic="$(cd "$REPO_ROOT" && grep -rn "superteam:ic\b" skills agents README.md || true)"
    if [[ -z "$ic" ]]; then
        pass "no reference to superteam:ic remains"
    else
        fail "no reference to superteam:ic remains"
        printf '%s\n' "$ic" | sed 's/^/    /'
    fi

    echo ""
    if [[ "$FAILURES" -ne 0 ]]; then
        echo "FAILED: $FAILURES assertion(s)."
        exit 1
    fi
    echo "PASS"
}

main "$@"
