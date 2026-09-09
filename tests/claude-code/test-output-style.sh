#!/usr/bin/env bash
# Static tests for the plugin output style in output-styles/: the team-lead
# register ships as superteam-lead.md and its frontmatter declares the four
# fields the harness reads (name, description, keep-coding-instructions,
# force-for-plugin), each exactly once. A field outside the frontmatter, or a
# second copy of one, is not read as a field at all.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
STYLE="$REPO_ROOT/output-styles/superteam-lead.md"

FAILURES=0
pass() { echo "  [PASS] $1"; }
fail() {
    echo "  [FAIL] $1"
    FAILURES=$((FAILURES + 1))
}

main() {
    echo "=== Test: output-style ==="

    # (a) the style file exists
    if [[ -f "$STYLE" ]]; then
        pass "output-styles/superteam-lead.md exists"
    else
        fail "output-styles/superteam-lead.md exists"
        echo ""
        echo "FAILED: $FAILURES assertion(s)."
        exit 1
    fi

    # (b) it opens with a frontmatter block
    local front
    front="$(awk 'NR == 1 && $0 == "---" { inside = 1; next }
                  inside && $0 == "---" { exit }
                  inside { print }' "$STYLE")"
    if [[ -n "$front" ]]; then
        pass "superteam-lead.md opens with a --- frontmatter block"
    else
        fail "superteam-lead.md opens with a --- frontmatter block"
    fi

    # (c) each field appears exactly once at line start inside the
    #     frontmatter - not later in the body, not twice
    local field count
    for field in 'name:' 'description:' 'keep-coding-instructions: true' 'force-for-plugin: true'; do
        count="$(printf '%s\n' "$front" | grep -c "^$field" || true)"
        if [[ "$count" -eq 1 ]]; then
            pass "frontmatter has one '$field'"
        else
            fail "frontmatter has one '$field' (found $count)"
        fi
    done

    # (d) the name field names the style the README and docs point at
    if printf '%s\n' "$front" | grep -q '^name: superteam-lead$'; then
        pass "frontmatter declares name: superteam-lead"
    else
        fail "frontmatter declares name: superteam-lead"
    fi

    echo ""
    if [[ "$FAILURES" -ne 0 ]]; then
        echo "FAILED: $FAILURES assertion(s)."
        exit 1
    fi
    echo "PASS"
}

main "$@"
