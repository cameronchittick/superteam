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
    done < <(grep -rn 'subagent_type: *"[^"]*"' "$SKILLS" | grep -v 'superteam:<role>')
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

    # (e) every roster agent claims and completes its own task on the
    #     shared task list
    local missing_task=0 role
    for role in "${ROSTER[@]}"; do
        if ! grep -qE "task list|TaskUpdate" "$AGENTS/$role.md"; then
            echo "    $role.md missing 'task list' or 'TaskUpdate'"
            missing_task=$((missing_task + 1))
        fi
    done
    if [[ "$missing_task" -eq 0 ]]; then
        pass "every roster agent mentions the shared task list"
    else
        fail "every roster agent mentions the shared task list ($missing_task missing)"
    fi

    # (f) the false "repeated idle notices" claim is gone
    local idle
    idle="$(grep -rln "repeated idle notices" "$AGENTS"/*.md 2>/dev/null || true)"
    if [[ -z "$idle" ]]; then
        pass "no agent file claims 'repeated idle notices'"
    else
        fail "no agent file claims 'repeated idle notices'"
        echo "    found in: $idle"
    fi

    # (g) reviewer may SendMessage the implementer for a clarifying question
    if grep -q "SendMessage" "$AGENTS/reviewer.md"; then
        pass "agents/reviewer.md mentions SendMessage"
    else
        fail "agents/reviewer.md mentions SendMessage"
    fi

    # (h) implementer/writer/integrator warn against hand-editing task files
    local missing_hand=0 role
    for role in implementer writer integrator; do
        if ! grep -qF '~/.claude/tasks' "$AGENTS/$role.md"; then
            echo "    $role.md missing '~/.claude/tasks'"
            missing_hand=$((missing_hand + 1))
        fi
    done
    if [[ "$missing_hand" -eq 0 ]]; then
        pass "implementer/writer/integrator warn against hand-editing ~/.claude/tasks"
    else
        fail "implementer/writer/integrator warn against hand-editing ~/.claude/tasks ($missing_hand missing)"
    fi

    # (i) implementer.md and writer.md declare a tools: allowlist with Edit
    #     and Write, and no Agent
    local role
    for role in implementer writer; do
        local tools_line
        tools_line="$(grep '^tools:' "$AGENTS/$role.md" || true)"
        if [[ -n "$tools_line" ]] && grep -q 'Edit' <<<"$tools_line" && grep -q 'Write' <<<"$tools_line" && ! grep -qw 'Agent' <<<"$tools_line"; then
            pass "$role.md has tools: with Edit, Write, and no Agent"
        else
            fail "$role.md has tools: with Edit, Write, and no Agent"
            echo "    tools line: ${tools_line:-<none>}"
        fi
    done

    # (j) integrator.md declares a tools: allowlist with Edit and no Write
    local integrator_tools
    integrator_tools="$(grep '^tools:' "$AGENTS/integrator.md" || true)"
    if [[ -n "$integrator_tools" ]] && grep -q 'Edit' <<<"$integrator_tools" && ! grep -qw 'Write' <<<"$integrator_tools"; then
        pass "integrator.md has tools: with Edit and no Write"
    else
        fail "integrator.md has tools: with Edit and no Write"
        echo "    tools line: ${integrator_tools:-<none>}"
    fi

    # (k) an explicit tools: allowlist is exact — Claude Code does not add
    #     SendMessage, ToolSearch or the Task tools to an allowlisted agent
    #     (verified 2.1.263), so every allowlisted agent must name them
    local f role
    for role in implementer writer reviewer integrator researcher skeptic; do
        f="$AGENTS/$role.md"
        grep -q '^maxTurns: [0-9]' "$f" && pass "agents/$role.md sets maxTurns" || fail "agents/$role.md sets maxTurns"
        grep -q '^## Claiming work (teammate)' "$f" && pass "agents/$role.md carries the claim rule" || fail "agents/$role.md carries the claim rule"
        grep -q "ends with \`\[$role\]\`" "$f" && pass "agents/$role.md claim rule names its own role tag" || fail "agents/$role.md claim rule names its own role tag"
        grep -qi 'never edit `~/.claude/tasks/\*\*`' "$f" && pass "agents/$role.md forbids hand-editing tasks" || fail "agents/$role.md forbids hand-editing tasks"
        grep -q 'model: inherit' "$f" && fail "agents/$role.md must not use model: inherit" || pass "agents/$role.md has an explicit model"
    done
    for role in implementer writer integrator; do
        grep -q '^tools: .*ToolSearch, TaskList, TaskGet, TaskUpdate, SendMessage' "$AGENTS/$role.md" && pass "agents/$role.md allows the team tools" || fail "agents/$role.md allows the team tools"
    done
    for role in implementer writer; do
        grep -q '^tools: .*EnterWorktree, ExitWorktree' "$AGENTS/$role.md" && pass "agents/$role.md allows EnterWorktree/ExitWorktree" || fail "agents/$role.md allows EnterWorktree/ExitWorktree"
        grep -q '^## Isolating (teammate)' "$AGENTS/$role.md" && pass "agents/$role.md has the Isolating section" || fail "agents/$role.md has the Isolating section"
        grep -q 'first command inside it is `git merge' "$AGENTS/$role.md" && pass "agents/$role.md merges the lane first" || fail "agents/$role.md merges the lane first"
    done
    for role in reviewer skeptic; do
        grep -q '^memory: project' "$AGENTS/$role.md" && pass "agents/$role.md has memory: project" || fail "agents/$role.md has memory: project"
    done

    # (k2) waiting on the lead never leaves a task in_progress: a turn that
    #      ends holding one re-fires the completion gate
    for role in implementer writer reviewer integrator researcher skeptic; do
        if sed -n '/^## Claiming work (teammate)/,/^## /p' "$AGENTS/$role.md" | grep -q 'status: pending'; then
            pass "agents/$role.md claiming section has the waiting rule"
        else
            fail "agents/$role.md claiming section has the waiting rule"
        fi
        grep -q '\.declined/' "$AGENTS/$role.md" && pass "agents/$role.md documents declining a task" || fail "agents/$role.md documents declining a task"
    done
    grep -q 'Never spin' "$AGENTS/integrator.md" && pass "agents/integrator.md says never spin" || fail "agents/integrator.md says never spin"
    for role in implementer writer; do
        grep -q 'never as a teammate' "$AGENTS/$role.md" && pass "agents/$role.md scopes haiku to subagent dispatch" || fail "agents/$role.md scopes haiku to subagent dispatch"
    done

    # (k3) roster model defaults: implementer/writer default to the
    #      worker model and reviewer to the review model (both opus, either
    #      literal or as the userConfig placeholder); researcher and
    #      integrator stay sonnet; skeptic stays opus
    local model_line
    for role in implementer writer; do
        model_line="$(grep '^model:' "$AGENTS/$role.md" || true)"
        if [[ "$model_line" == 'model: opus' || "$model_line" == 'model: ${user_config.worker_model}' ]]; then
            pass "agents/$role.md defaults to the worker model (opus)"
        else
            fail "agents/$role.md defaults to the worker model (opus)"
            echo "    model line: ${model_line:-<none>}"
        fi
    done
    model_line="$(grep '^model:' "$AGENTS/reviewer.md" || true)"
    if [[ "$model_line" == 'model: opus' || "$model_line" == 'model: ${user_config.review_model}' ]]; then
        pass "agents/reviewer.md defaults to the review model (opus)"
    else
        fail "agents/reviewer.md defaults to the review model (opus)"
        echo "    model line: ${model_line:-<none>}"
    fi
    for role in researcher integrator; do
        if [[ "$(grep '^model:' "$AGENTS/$role.md" || true)" == 'model: sonnet' ]]; then
            pass "agents/$role.md stays sonnet"
        else
            fail "agents/$role.md stays sonnet"
        fi
    done
    if [[ "$(grep '^model:' "$AGENTS/skeptic.md" || true)" == 'model: opus' ]]; then
        pass "agents/skeptic.md stays opus"
    else
        fail "agents/skeptic.md stays opus"
    fi

    # (k4) the userConfig keys exist in the plugin manifest with opus
    #      defaults, and implementer/writer/reviewer name their key
    local manifest="$REPO_ROOT/.claude-plugin/plugin.json"
    local key
    for key in worker_model review_model; do
        if grep -A5 "\"$key\"" "$manifest" 2>/dev/null | grep -q '"default": *"opus"'; then
            pass "plugin.json declares userConfig $key with default opus"
        else
            fail "plugin.json declares userConfig $key with default opus"
        fi
    done
    for role in implementer writer; do
        grep -qF 'user_config.worker_model' "$AGENTS/$role.md" && pass "agents/$role.md names user_config.worker_model" || fail "agents/$role.md names user_config.worker_model"
    done
    grep -qF 'user_config.review_model' "$AGENTS/reviewer.md" && pass "agents/reviewer.md names user_config.review_model" || fail "agents/reviewer.md names user_config.review_model"

    # (k5) skills preload: each role's `skills:` frontmatter names exactly
    #      the skills its work needs, plugin-scoped
    local want skills_line
    for entry in \
        "implementer:superteam:test-driven-development, superteam:verification-before-completion" \
        "writer:superteam:test-driven-development, superteam:verification-before-completion" \
        "reviewer:superteam:requesting-code-review" \
        "integrator:superteam:finishing-a-development-branch"; do
        role="${entry%%:*}"
        want="${entry#*:}"
        skills_line="$(grep '^skills:' "$AGENTS/$role.md" || true)"
        if [[ "$skills_line" == "skills: $want" ]]; then
            pass "agents/$role.md preloads: $want"
        else
            fail "agents/$role.md preloads: $want"
            echo "    skills line: ${skills_line:-<none>}"
        fi
    done

    # (k6) the false "the skills field is ignored" claim is gone from every
    #      agent that preloads, and each says to invoke them by hand if the
    #      teammate spawn did not preload them
    local ignored
    ignored="$(grep -ln 'skills` field is ignored' "$AGENTS"/implementer.md "$AGENTS"/writer.md "$AGENTS"/reviewer.md "$AGENTS"/integrator.md "$AGENTS"/researcher.md 2>/dev/null || true)"
    if [[ -z "$ignored" ]]; then
        pass "no preloading agent claims the skills field is ignored"
    else
        fail "no preloading agent claims the skills field is ignored"
        echo "    found in: $ignored"
    fi
    for role in implementer writer reviewer integrator researcher; do
        if grep -qF 'invoke each skill named in `skills:` with `Skill`' "$AGENTS/$role.md"; then
            pass "agents/$role.md falls back to invoking the skills by hand"
        else
            fail "agents/$role.md falls back to invoking the skills by hand"
        fi
    done

    # (k6b) the hedge is gone: a teammate spawn does NOT preload `skills:`
    #       (lead probe 2026-09-06)
    local hedged
    hedged="$(grep -ln 'may not preload' "$AGENTS"/*.md 2>/dev/null || true)"
    if [[ -z "$hedged" ]]; then
        pass "no agent file hedges about teammate skill preloading"
    else
        fail "no agent file hedges about teammate skill preloading"
        echo "    found in: $hedged"
    fi
    for role in implementer writer reviewer integrator skeptic researcher; do
        if grep -q 'a teammate spawn does not' "$AGENTS/$role.md"; then
            pass "agents/$role.md states that a teammate spawn does not preload skills"
        else
            fail "agents/$role.md states that a teammate spawn does not preload skills"
        fi
    done

    # (k7) implementer.md and writer.md read every Standards: file before
    #      writing anything
    for role in implementer writer; do
        if grep -qE '^([0-9]+\.|[[:space:]]*\([a-g]\)).*`Standards:`' "$AGENTS/$role.md" \
            && grep -q 'before writing' "$AGENTS/$role.md"; then
            pass "agents/$role.md reads the Standards: files before writing"
        else
            fail "agents/$role.md reads the Standards: files before writing"
        fi
    done

    # (k8) implementer.md carries one work cadence, in order: TDD at the
    #      seam, typecheck, focused test file while iterating, full suite
    #      once before the commit, review seats as the gate
    local cadence_ok=1 prev=0 pos phrase
    for phrase in 'superteam:test-driven-development' 'typecheck' 'focused test file' 'full suite once' 'review seats'; do
        pos="$(grep -nF "$phrase" "$AGENTS/implementer.md" | head -1 | cut -d: -f1)"
        if [[ -z "$pos" ]]; then
            echo "    implementer.md missing: $phrase"
            cadence_ok=0
        elif [[ "$pos" -lt "$prev" ]]; then
            echo "    implementer.md out of order at: $phrase (line $pos after line $prev)"
            cadence_ok=0
        else
            prev="$pos"
        fi
    done
    if [[ "$cadence_ok" -eq 1 ]]; then
        pass "implementer.md states the work cadence in order"
    else
        fail "implementer.md states the work cadence in order"
    fi

    # (k9) never self-review as the gate: the review seats are
    for role in implementer writer; do
        if grep -q 'superteam:requesting-code-review' "$AGENTS/$role.md"; then
            pass "agents/$role.md names the superteam:requesting-code-review rubrics"
        else
            fail "agents/$role.md names the superteam:requesting-code-review rubrics"
        fi
    done

    # (k10) every skill reference in agent text is superteam:-prefixed. A
    #       bare name is a skill that will not resolve.
    local bare skill
    bare=""
    for skill in test-driven-development verification-before-completion \
        requesting-code-review finishing-a-development-branch systematic-debugging; do
        # A hit not preceded by "superteam:" or "skills/" is a bare name.
        bare+="$(grep -rn "$skill" "$AGENTS"/*.md 2>/dev/null \
            | grep -v "superteam:$skill" \
            | grep -v "skills/$skill" || true)"
    done
    if [[ -z "$bare" ]]; then
        pass "every skill reference in agents/ is superteam:-prefixed"
    else
        fail "every skill reference in agents/ is superteam:-prefixed"
        printf '%s\n' "$bare" | sed 's/^/    /'
    fi

    # (k11) no agent file — skeptic included — still claims the skills
    #       field is ignored
    local ignored_any
    ignored_any="$(grep -ln 'skills` field is ignored' "$AGENTS"/*.md 2>/dev/null || true)"
    if [[ -z "$ignored_any" ]]; then
        pass "no agent file claims the skills field is ignored"
    else
        fail "no agent file claims the skills field is ignored"
        echo "    found in: $ignored_any"
    fi

    # (k12) the researcher runs in the background as a subagent, cites
    #       primary sources, and persists findings to exactly one new file
    local r="$AGENTS/researcher.md"
    grep -q '^background: true$' "$r" \
        && pass "agents/researcher.md sets background: true" \
        || fail "agents/researcher.md sets background: true"
    local denied
    denied="$(grep '^disallowedTools:' "$r" || true)"
    if [[ "$denied" == *Edit* && "$denied" == *NotebookEdit* && "$denied" != *Write* ]]; then
        pass "agents/researcher.md denies Edit and NotebookEdit but allows Write"
    else
        fail "agents/researcher.md denies Edit and NotebookEdit but allows Write"
        echo "    disallowedTools: ${denied:-<none>}"
    fi
    local phrase
    for phrase in 'docs/superteam/research/' 'primary' 'URL + section' 'file:line'; do
        grep -qiF "$phrase" "$r" \
            && pass "agents/researcher.md states: $phrase" \
            || fail "agents/researcher.md states: $phrase"
    done
    grep -qF 'exactly one' "$r" \
        && pass "agents/researcher.md caps the findings file at exactly one" \
        || fail "agents/researcher.md caps the findings file at exactly one"
    grep -qF '`Lead:`' "$r" \
        && pass "agents/researcher.md reports to the name on the Lead: line" \
        || fail "agents/researcher.md reports to the name on the Lead: line"

    # (l) every body opens by saying who the agent is — in split-pane mode
    #     the body replaces the system prompt and no dispatch template
    #     reaches it
    local opening=0 role
    for role in "${ROSTER[@]}"; do
        if ! sed -n '9,14p' "$AGENTS/$role.md" | grep -q "^You are "; then
            echo "    $role.md has no 'You are ...' opening paragraph"
            opening=$((opening + 1))
        fi
    done
    if [[ "$opening" -eq 0 ]]; then
        pass "every roster agent opens by saying who it is"
    else
        fail "every roster agent opens by saying who it is ($opening missing)"
    fi

    echo ""
    if [[ "$FAILURES" -ne 0 ]]; then
        echo "FAILED: $FAILURES assertion(s)."
        exit 1
    fi
    echo "PASS"
}

main "$@"
