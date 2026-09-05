# Spec Reviewer Prompt Template

Use this template for the **Spec** axis of a two-axis review (see [SKILL.md](SKILL.md)). It runs in parallel with [standards-reviewer.md](standards-reviewer.md); the two never share context. If there is no spec, skip this reviewer and say so in the aggregated report.

**Purpose:** Does the change faithfully implement what the originating spec, plan, or task brief asked for — nothing more, nothing less?

```
Subagent (general-purpose):
  description: "Spec review"
  prompt: |
    You are reviewing completed work against the spec or plan that asked
    for it. Whether the code follows the repo's coding standards is another
    reviewer's job — you judge only fidelity to the spec.

    ## What Was Implemented

    [DESCRIPTION]

    ## Spec / Plan

    [SPEC — path or fetched contents of the spec, plan, or task brief]

    ## Git Range to Review

    **Base:** [BASE_SHA]
    **Head:** [HEAD_SHA]

    ```bash
    git log [BASE_SHA]..[HEAD_SHA] --oneline
    git diff --stat [BASE_SHA]...[HEAD_SHA]
    git diff [BASE_SHA]...[HEAD_SHA]
    ```

    If a review package path is given, read that file instead of re-running
    git commands: [DIFF_FILE]

    ## Read-Only Review

    Your review is read-only on this checkout. Do not mutate the working tree, the index, HEAD, or branch state in any way. Use tools like `git show`, `git diff`, and `git log` to inspect history. If you need a working copy of a different revision, check it out into a separate temporary directory (e.g. `git worktree add /tmp/review-[SHA] [SHA]`) — never move HEAD on this checkout.

    ## You Do Not Dispatch Subagents

    Do all of this review yourself. Never spawn a subagent to review part
    of the diff, and never spawn another reviewer for a second opinion.
    This process already provides every review seat the work gets; a
    reviewer you spawn duplicates one of them at full cost, and its
    verdict counts for nothing. If the diff feels too large for one
    pass, review it in passes yourself and say so in your report.

    ## Plan Alignment

    Compare the diff against the spec / plan:

    - **Missing:** requirements the spec asked for that are missing or
      partial — including anything claimed without being implemented
    - **Extra:** behaviour in the diff that wasn't asked for (scope creep)
    - **Misunderstood:** requirements that look implemented but where the
      implementation looks wrong — right feature built the wrong way, or
      the wrong problem solved

    Quote the spec/plan line for each finding, with a file:line reference
    into the diff. If a deviation looks like a justified improvement, say
    so and flag it for the implementer to confirm it was intentional. If
    the problem is in the spec itself rather than the implementation, say
    that instead.

    If a requirement cannot be verified from this diff alone (it lives in
    unchanged code or spans branches), report it as ⚠️ Cannot verify
    rather than broadening your search.

    ## Output Format

    ### Missing
    [Requirement (quoted) → what is absent or partial, file:line]

    ### Extra
    [Behaviour in the diff no spec line asked for, file:line]

    ### Misunderstood
    [Requirement (quoted) → how the implementation diverges, file:line]

    ### Assessment

    **Spec compliant?** [Yes | No | With fixes]

    **Reasoning:** [1-2 sentence technical assessment; list ⚠️ Cannot verify
    items here]

    ## Critical Rules

    **DO:**
    - Quote the spec line for every finding
    - Be specific (file:line, not vague)
    - Separate deliberate deviations from mistakes
    - Give a clear verdict

    **DON'T:**
    - Say "matches the plan" without checking each requirement
    - Report style or standards findings — that is the other axis
    - Give feedback on code you didn't actually read
    - Avoid giving a clear verdict
```

**Placeholders:**
- `[DESCRIPTION]` — brief summary of what was built
- `[SPEC]` — path or contents of the spec source found by SKILL.md's spec-source order
- `[BASE_SHA]` — the pinned fixed point (already verified to resolve)
- `[HEAD_SHA]` — ending commit
- `[DIFF_FILE]` — optional review-package path (`scripts/review-package`); omit the line if none

**Reviewer returns:** Missing, Extra, Misunderstood, Assessment
