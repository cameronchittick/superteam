# Parallel ICs: splitting, messaging, and an observer seat

## Conclusion

Interface-first splitting already works — both dogfood runs show zero `Files owned:` overlap rejections across 3 concurrent writing seats (7.0.0) and a writer→implementer dependency chain (7.3.0), so the "one writer at a time" cost is not a task-graph-design problem, it's the in-process-teammate `EnterWorktree` bug that made split panes mandatory (SKILL.md:92-95). Teammate messaging is real and lateral (docs confirm direct `SendMessage`, no shared context) but neither ledger records a single reviewer→implementer clarifying question in a completed run — the one measured case of a reviewer needing more information (task 25's Register-line finding) went through the fix-round protocol, not a lateral message. An observer/per-commit reviewer would not have shortened the one fix round with timestamps to check: task 25 was a single commit (e6acc66, 22:44:23), so "per-commit" review is identical to the review that already ran at task-end — the finding surfaced in 4 minutes either way (fix committed 22:55:31, merged 22:57:48), and the mechanism to test the observer's real claim (catching a fix mid-multi-commit-task) is unmeasured because no sampled task had more than one commit before review.

## Splitting evidence

| Run | Task graph shape | Overlap rejections | Serialization mechanism |
|---|---|---|---|
| 2026-09-05 universal-agent-team-system (7.0.0) | T1 hooks / T2 emitter / T3 agents / T4 SDD / T5 dispatching / T6 using-superteam / T7 audit — 3 concurrent writing seats (impl-1, writer-1, writer-2) claiming #5/#9/#8 19-36s apart | 0 found in ledger | None needed for the concurrent trio; preflight scan (progress.md:6-15) found file/interface pairs "ok" by construction, not by a Depends-on edge |
| 2026-09-09 report-register (7.3.0) | Task 23 (doc, writer), 24 (style file, writer), 25 (agents+SDD prompts, implementer), 26 (roster test, implementer) | 0 found in ledger | Interface-first: preflight ruled "Task 4 Depends on Task 2, Task 3 (was none; would red the lane)" (progress.md:16) — task graph line 20 confirms "26 blockedBy 36, 37" (the merge tasks of 24 and 23), i.e. the test task waited for the style file and doc to land in the lane before it could assert against them |

Both runs show the *hook* (`hooks/task-created-check:75-113`) doing the non-overlap enforcement — it rejects any `Task N:` creation whose `Files owned:` list intersects an open task's list unless a `Depends on:` line names that task's family (task-created-check:12-18, 95-107). Neither ledger records a rejection firing, so in two runs (7 + 4 = 11 plan tasks) the split-by-Files-owned design produced zero same-file collisions — the splits (docs/style/agents/tests) were already non-overlapping by task-graph construction, not because collisions were caught and serialized after the fact. This is consistent with, not proof against, the brief's premise that overlap forces serial ordering: the ordering observed (26 blockedBy 36,37) was a genuine interface-first dependency (test-after-style), not an overlap the hook rejected.

## Messaging evidence

Docs (code.claude.com/docs/en/agent-teams, "Context and communication"): "Teammate messaging: send a message to one specific teammate by name... The lead assigns every teammate a name when it spawns them, and any teammate can message any other by that name." Same page, "Architecture" table: each agent's mailbox is a JSON file at `~/.claude/teams/{team}/inboxes/{agent}.json`; delivery is automatic, no shared context — "The lead's conversation history does not carry over" to a spawned teammate.

`agents/reviewer.md:57`: "You may also `SendMessage` the implementer by name for a clarifying question about the change; verdicts go only to the lead." This is the exact lateral channel the brief asks about — it exists in the agent body.

Measured use in the two ledgers: **zero** reviewer→implementer lateral messages recorded. The only `SendMessage` activity the ledgers log is teammate→lead (2026-09-05 progress.md:25,30 — a writer's malformed `SendMessage` call, and lead-visibility findings about messages "never surfaced in my context during a long lead turn"). The report-register run's fix round for task 25 (progress.md:30) shows the reviewer reporting a finding to the lead, the lead creating a fix task, and the same implementer (by name, per SKILL.md:739-742 rounds 1-3) resuming via `SendMessage` from the *lead* — not a direct reviewer-to-implementer negotiation. **Unmeasured**: whether reviewer→implementer lateral messages ever fire in a run large enough to need them; neither sampled ledger is that large.

## Observer seat

The brief's candidate mechanism: a reviewer teammate watching commits land, per-commit, instead of a single verdict at task-end. The only timed fix-round in the sampled ledgers:

| Event | Commit | Timestamp |
|---|---|---|
| Task 25 implement (one commit, 8 files) | e6acc66 | 22:44:23 |
| Spec review finds "Register line outside the prompt fence in 3 files" (Important) | — (verdict, not a commit) | between 22:44:23 and 22:55:31 |
| Fix round 1 commit | 2300d28 | 22:55:31 |
| Task 25 merged (after re-review) | b32d037 | 22:57:48 |

Task 25 was **one commit** before review — there was nothing for a per-commit observer to see earlier than the end-of-task reviewer already saw. The full loop (implement → find → fix → merge) took ~13 minutes. This does not support the observer seat shortening *this* loop; it also does not refute the seat's real claim (catching drift *within* a multi-commit task before the task ends), because no sampled task in either ledger had more than one commit before its first review — **unmeasured** for the case the seat is actually built for. Token cost is measurable in principle (reviewer turns × commits) but the ledgers don't log teammate turn counts, only wall-clock and commit hashes — **unmeasured**.

## What breaks

- **Same-file edits in one checkout**: docs (agent-teams.md, "Avoid file conflicts"): "Two teammates editing the same file leads to overwrites. Break the work so each teammate owns a different set of files." This is exactly what `task-created-check`'s Files-owned rule enforces before a task is even created (task-created-check:95-113) — the tool-level guard and the docs' stated hazard match.
- **In-process EnterWorktree**: SKILL.md:92-95 — "an in-process teammate shares your session's process cwd, so its `EnterWorktree` moves you and every other teammate with it — a dogfood run landed three implementers' edits in one worktree that way" (confirmed live: 2026-09-05 progress.md:20, "Three implementers entered three worktrees; all edits landed in the last-entered one"). This is *the* mechanism forcing split-pane mode (tmux) for every writing seat, not a task-splitting limitation — docs confirm split-pane teammates each "have a full view of their own terminal" (agent-teams.md, "Talk to teammates directly").
- **Shared test suites**: not directly evidenced in either ledger (no `bin/superteam-test` full-checkout run recorded while two branches were dirty) — **unmeasured**; the worktree-cost-assessment doc (docs/superteam/research/2026-09-09-worktree-cost-assessment.md) establishes worktrees isolate each seat's dirty tree from the others', which sidesteps this specific hazard by construction as long as writing seats stay in worktrees.
- **Moving trunk**: covered separately in the worktree-cost-assessment doc (11 trunk-into-lane rebases in Run Wild since 2026-09-05) — not re-verified here.

## Evidence

- `.superteam/sdd/2026-09-05-universal-agent-team-system/progress.md:6-15,18-19` — preflight scan table, 3-seat pool.
- `.superteam/sdd/2026-09-09-report-register/progress.md:2-40` — full run; lines 20 (task graph), 24-26 (Task 25 commit/awaiting review), 30 (fix round finding + timestamps via git), 34 (merge).
- `hooks/task-created-check:12-18,95-113` — Files-owned overlap rejection logic and the Depends-on exemption.
- `skills/superteam-driven-development/SKILL.md:92-95,739-757` — EnterWorktree cwd hazard; fix-round resume-by-name protocol.
- `agents/reviewer.md:25-27,54-57` — teammate claim/pending protocol; lateral SendMessage to implementer, verdicts to lead only.
- `agents/implementer.md:20-24` — same claim protocol, mirrored.
- `git log --format='%h %ad %s' -1 e6acc66 2300d28 b32d037 9f4a176` — commit timestamps used for the fix-round timing table.
- https://code.claude.com/docs/en/agent-teams — "Compare with subagents" table (context/communication/coordination); "Context and communication" (mailbox, no shared history, automatic delivery); "Avoid file conflicts" (same-file hazard); "Talk to teammates directly" (split-pane full terminal view); "Limitations" (no nested teams, one team per session).
- `docs/superteam/research/2026-09-09-worktree-cost-assessment.md` — cited for trunk-movement and same-checkout-dirty-tree claims, not re-derived here.

## Open

The one point that would settle whether the observer seat earns its cost: a task with 3+ commits before its first review, timestamped, so a per-commit reviewer's hypothetical earlier catch can be compared against the actual end-of-task catch. Neither sampled ledger contains one — both fix-round tasks examined were single-commit. Re-run this check against a larger plan (7.3.0's report-register run tops out at 4 implement tasks) or instrument the next SDD run to log reviewer teammate turn counts alongside commit timestamps.

## Skeptic verdicts (superteam:skeptic, 2026-09-09)

Splitting does not buy concurrency under the branch tier; the worktree tier is the whole answer, and there is nothing new to build.

1. **keep — interface-first splitting.** Free and already load-bearing: `hooks/task-created-check:95-113` rejects Files-owned overlap with no `Depends on:` edge; 11 plan tasks across two runs, 0 rejections.
2. **kill — splitting as the answer to "more ICs at once".** Files-owned non-overlap prevents file collisions, not checkout collisions; three disjoint seats are still three dirty trees and one checkout holds one.
3. **kill — test-writer + implementer as two seats on one task.** Two writers on one Files-owned set, and the one case the hook waves through (same-family exemption, `task-created-check:88`): an unguarded race by design; it also splits red-green across two contexts.
4. **shrink — docs/writer in parallel.** Evidenced only in a three-worktree run; under the branch tier it is the two-writer escalation trigger, not a branch-tier capability.
5. **keep — lateral messaging as written.** `agents/reviewer.md:56-57` already allows the clarifying question with verdicts still going to the lead.
6. **kill — messaging as seam negotiation.** Speculative Generality: 0 lateral messages in 11 tasks, and the overlap guard fires only at TaskCreate, so a renegotiated seam goes unguarded.
7. **kill — the observer seat.** Middle Man and unmeasured: every sampled task was one commit before review, so per-commit review is identical to the review that already ran; it emits messages not verdicts and burns the fifth teammate slot.
8. **keep — the worktree tier as the answer to the failure modes, unchanged.** Same-file edits already hook-guarded; the two-dirty-branches suite hazard is unmeasured; moving trunk is real only in Run Wild and already a trigger. Net new work: zero.
9. **shrink — this page's point 1.** The one-writer cost under the branch tier is "one checkout holds one dirty branch", not the in-process `EnterWorktree` bug; the fix is a second checkout, not split panes.

**Try first (one change):** make the tier choice automatic — escalate a plan from branch tier to worktree tier the moment the task graph contains two or more writing tasks that are simultaneously unblocked. One rule in the tier-selection text; no new seat, channel or hook.

**Measure it** on the next SDD run of six or more plan tasks: (a) max writing tasks in_progress at once, (b) dirty-tree collisions in the lead's checkout (stashes, forced branch switches, lost edits), (c) wall clock per plan task against the 7.3.0 four-task baseline. Worked if (a) ≥ 2 with (b) = 0 and (c) not worse. If (a) never exceeds 1, the branch tier was right all along.

**Cut this first:** the observer seat.
