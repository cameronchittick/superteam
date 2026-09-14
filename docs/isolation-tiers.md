# Isolation tiers

Isolation is chosen per task at plan time from what the task needs, not
applied to every task. A task says where it runs — trunk, a branch in the lead's
checkout, a worktree, or a provisioned lane — on its
`**Isolation:**` header line, and the tier is picked from what the task will
actually do: how many writing seats hold uncommitted work at once, whether a
review seat must sit between the work and trunk, and whether a second dev
server or database has to run. Trunk is the default; every other tier has to
be earned by a trigger below.

Why: the evidence page found the per-task worktree earned its cost only when
two or more seats were dirty at once, and Run Wild paid a 2.3 GB install and a
database per lane for concurrency that mostly never arrived. See
[docs/superteam/research/2026-09-09-worktree-cost-assessment.md](superteam/research/2026-09-09-worktree-cost-assessment.md)
for the measurements and the accepted verdicts behind this page.

## The tiers

| Tier | Choose it when | Mechanism | Review | Merge |
|---|---|---|---|---|
| **trunk** (default) | one writing seat, the only thing writing in this repo, and no review seat between the work and trunk | the seat commits straight on `<base>` in the lead's own checkout; no branch, no worktree | the lead reads the commits on `<base>` after they land; a bad commit is reverted | none — the work is already on `<base>` |
| **branch** | a review seat — a reviewer IC or a human ruling — must sit between the work and trunk, or a second seat is live in this repo without both writing at once | `git switch -c task-N <base>` in the lead's own checkout; the seat is a teammate with no isolation | reviewer diffs `<base>..task-N` | the lead: `git merge --no-ff task-N`, run the suite, `git branch -d task-N`; no integrator seat |
| **worktree** | two or more writing seats must write in this repo at the same time | `EnterWorktree` (teammate) or `isolation: "worktree"` (subagent) — a plain `git worktree add`, nothing provisioned | reviewer diffs `<base>..worktree-task-N-impl` | an integrator seat only when merges are frequent enough to need serialising (three or more worktree-tier tasks in the plan); otherwise the lead merges as in the branch tier |
| **provisioned** | a second running dev server or database is required — a migration under test, a running app for review | the worktree tier plus the repo's own provisioning script, run here and nowhere else | as worktree | as worktree |

`<base>` is the plan's integration branch: trunk by default; a lane branch only when the plan has two or more tasks merging before trunk (the plan header's `**Integration:**` line). The tier is chosen per task at intake — when the plan is written, or when a one-task brief arrives — and travels on the task as its `**Isolation:**` line; a task with no line is trunk tier. A branch for a lone writer with no review seat is a merge commit for nothing. A repo that provisions (install, env, database) does it only for the provisioned tier and only from its own script — never on worktree creation.

## Triggers for the branch, worktree and provisioned tiers

- A review seat must sit between the work and trunk — branch.
- A second seat is live in this repo but the two never write at once — branch.
- Two or more writing seats will hold uncommitted work at the same time.
- The branch will outlive trunk movement and needs rebase-in-place without
  disturbing the lead's checkout.
- Two dev servers or two databases must run at once — provisioned.
- Enough tasks that a trunk-visible half-done state is unacceptable —
  integration branch only, still no per-task worktrees.

## Escalation and what the ledger records

A plan escalates a task off trunk — to branch when a second seat goes live, to worktree whenever two or more writing tasks are unblocked at the same time. The lead records in the ledger, per task, the maximum number of concurrent writers, any dirty-checkout collision, and wall-clock time from claim to merge, so the next run of six or more tasks can be judged against the 7.3.0 baseline.

### The second-seat gate

Adding a second writing seat to a task, or to a repo where one writing seat is live, is a gate of three steps, in order, and the new seat is not live until all three are done. A seat briefed as the only writer will finish alone, and its report will be true to what it knew and false to what the lead knows.

1. The task's `Isolation:` line is set to worktree before anything else — `TaskUpdate` the description if it reads trunk or branch or has no line.
2. The split is written down once, naming the files each seat owns, and is sent to both seats before the second seat is spawned: the existing seat by `SendMessage`, the new seat in its spawn brief.
3. The existing seat acknowledges the split by message, or reports it has already finished, before the second seat is treated as live. A message to a working seat arrives only after its current turn ends, so the lead waits for the acknowledgement rather than assuming delivery.

## Sizing the work

Before anything is dispatched, the lead sizes the brief on five dimensions: how many files it touches; whether anything else is writing in the repo; the cost of a mistake; whether there is a design choice to make; how many independent pieces it has. The size sets which seats sit. It is a scale the lead reads for every brief, never a category the brief matches, and the lead's own hands are not on it: the lead does not implement, not even a one-line fix — a spawn costs seconds and keeps the lead's context for leading. A request that arrives straight from your human partner is sized and delegated exactly like a brief from above.

1. **One IC.** The smallest size: one implementer or writer on trunk, even for a one-line fix; the lead reads its commits after they land.
2. **Add the seat that answers the risk.** A design choice seats a skeptic before building; a costly failure seats a reviewer after.
3. **One IC per independent piece, at once.** Several independent pieces get a writing seat each, plus whatever step 2 seats each piece's own risk calls for.

Examples are illustrations, never the rule: a copy change is usually one IC and nothing more, but a copy change to a legal notice has a costly failure and gets a reviewer; a one-file schema migration is one task, but it has a design choice and a costly failure, so it gets both seats; three docs pages with nothing in common are three writers at once. The lead states the size it chose and the dimensions that drove it in its report and in the ledger, so the next brief can be calibrated against it.

Two Run Wild UI changes that took 40 minutes through implementer and reviewer seats would have sized at one IC each with no reviewer seated.

## The trunk flow

1. The task carries `Isolation: trunk` — or no `**Isolation:**` line at all,
   which means the same thing.
2. One implementer teammate works in the lead's own checkout on `<base>`, no
   branch, no worktree, no provisioning.
3. It commits straight on `<base>` and reports.
4. The lead reads the commits on `<base>` after they land and reverts a bad
   one (`git revert`).
5. `task-created-check` still guards `Files owned`.

## The branch-tier flow

1. `git switch -c task-N` in the lead's checkout (a review seat sits between
   the work and trunk, or a second seat is live), no lane, no worktree, no
   provisioning.
2. One implementer teammate, no isolation, on that branch.
3. Reviewer diffs `<base>..task-N`.
4. The lead merges and deletes the branch, no integrator.
5. `task-created-check` still guards `Files owned`.
