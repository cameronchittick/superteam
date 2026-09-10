# Isolation tiers

Isolation is chosen per task at plan time from what the task needs, not
applied to every task. A task says where it runs — the lead's own checkout, a
branch in that checkout, a worktree, or a provisioned lane — on its
`**Isolation:**` header line, and the tier is picked from what the task will
actually do: how many writing seats hold uncommitted work at once, and whether
a second dev server or database has to run. Branch is the default; every other
tier has to be earned by a trigger below.

Why: the evidence page found the per-task worktree earned its cost only when
two or more seats were dirty at once, and Run Wild paid a 2.3 GB install and a
database per lane for concurrency that mostly never arrived. See
[docs/superteam/research/2026-09-09-worktree-cost-assessment.md](superteam/research/2026-09-09-worktree-cost-assessment.md)
for the measurements and the accepted verdicts behind this page.

## The tiers

| Tier | Choose it when | Mechanism | Review | Merge |
|---|---|---|---|---|
| **solo** | the lead sized the brief at own hands — one small, safe, visible change, nothing else writing, small enough for its own context | the lead does it in its own checkout on `task-N`: test-first at the seam, one focused test, commit | no seat unless the sizing seats one; the lead verifies it running and your human partner looks | the lead: `git merge --no-ff task-N`, `git branch -d task-N` |
| **branch** (default) | where own hands ends — one IC, a seated reviewer, or a change too large to carry — and still one writing seat at a time in this repo | `git switch -c task-N <base>` in the lead's own checkout; the seat is a teammate with no isolation | reviewer diffs `<base>..task-N` | the lead: `git merge --no-ff task-N`, run the suite, `git branch -d task-N`; no integrator seat |
| **worktree** | two or more writing seats must write in this repo at the same time | `EnterWorktree` (teammate) or `isolation: "worktree"` (subagent) — a plain `git worktree add`, nothing provisioned | reviewer diffs `<base>..worktree-task-N-impl` | an integrator seat only when merges are frequent enough to need serialising (three or more worktree-tier tasks in the plan); otherwise the lead merges as in the branch tier |
| **provisioned** | a second running dev server or database is required — a migration under test, a running app for review | the worktree tier plus the repo's own provisioning script, run here and nowhere else | as worktree | as worktree |

`<base>` is the plan's integration branch: trunk by default; a lane branch only when the plan has two or more tasks merging before trunk (the plan header's `**Integration:**` line). The tier is chosen per task at intake — when the plan is written, or when a one-task brief arrives — and travels on the task as its `**Isolation:**` line; a task with no line is branch tier, solo is always written explicitly. A repo that provisions (install, env, database) does it only for the provisioned tier and only from its own script — never on worktree creation.

## Triggers for the worktree and provisioned tiers

- Two or more writing seats will hold uncommitted work at the same time.
- The branch will outlive trunk movement and needs rebase-in-place without
  disturbing the lead's checkout.
- Two dev servers or two databases must run at once — provisioned.
- Enough tasks that a trunk-visible half-done state is unacceptable —
  integration branch only, still no per-task worktrees.

## Escalation and what the ledger records

A plan escalates a task from the branch to the worktree tier whenever two or more writing tasks are unblocked at the same time. The lead records in the ledger, per task, the maximum number of concurrent writers, any dirty-checkout collision, and wall-clock time from claim to merge, so the next run of six or more tasks can be judged against the 7.3.0 baseline.

## Sizing the work

Before anything is dispatched, the lead sizes the brief on five dimensions: how many files it touches; whether anything else is writing in the repo; the cost of a mistake; whether there is a design choice to make; how many independent pieces it has. The size sets who does the work and which seats sit. It is a scale the lead reads for every brief, never a category the brief matches:

1. **Own hands.** One small, safe, visible change with nothing else in flight: the lead does it (solo tier), test-first, and your human partner looks.
2. **One IC.** One real task: one implementer or writer; the lead reviews its diff.
3. **Add the seat that answers the risk.** A design choice seats a skeptic before building; a costly failure seats a reviewer after.
4. **One IC per independent piece, at once.** Several independent pieces get a writing seat each, plus whatever step 3 seats each piece's own risk calls for.

Examples are illustrations, never the rule: a copy change is usually own hands, but a copy change to a legal notice has a costly failure and gets a reviewer; a one-file schema migration is one task, but it has a design choice and a costly failure, so it gets both seats; three docs pages with nothing in common are three own-hands changes or three writers at once, depending on what else is in flight. The lead states the size it chose and the dimensions that drove it in its report and in the ledger, so the next brief can be calibrated against it.

Two Run Wild UI changes that took 40 minutes through implementer and reviewer seats would have sized at own hands.

## The solo flow

1. The lead sizes the brief at own hands and writes `Isolation: solo` on the task.
2. `git switch -c task-N` in its own checkout.
3. A failing focused test at the seam, then the change.
4. The lead runs it and your human partner looks.
5. Merge and delete the branch; ledger tier, size, seats and wall clock.

## The branch-tier flow

1. `git switch -c task-N` in the lead's checkout, no lane, no worktree, no
   provisioning.
2. One implementer teammate, no isolation, on that branch.
3. Reviewer diffs `<base>..task-N`.
4. The lead merges and deletes the branch, no integrator.
5. `task-created-check` still guards `Files owned`.
