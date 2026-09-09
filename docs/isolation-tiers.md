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
| **solo** | the brief is one task, no migration, no money/auth/security/data surface, no other writer active, and the change is small enough for the lead's own context | the lead does it in its own checkout on `task-N`: test-first at the seam, one focused test, commit | no reviewer seat unless the brief asks for one or the diff turns out to touch a listed surface; the lead verifies it running and your human partner looks | the lead: `git merge --no-ff task-N`, `git branch -d task-N` |
| **branch** (default) | where solo ends — a second writer, a required reviewer, or a task too large for the lead to carry — and still one writing seat at a time in this repo | `git switch -c task-N <base>` in the lead's own checkout; the seat is a teammate with no isolation | reviewer diffs `<base>..task-N` | the lead: `git merge --no-ff task-N`, run the suite, `git branch -d task-N`; no integrator seat |
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

## Gates

Gates scale with what breaks if wrong; they do not run by default. Skeptic: only on a spec or plan that changes a data model or a contract, or that has three or more tasks. Reviewer: only where a slip costs money, auth, security or data, or where the brief asks for one. A UI, copy or docs change your human partner can see for themselves gets neither: the lead verifies it running and your human partner looks. The ledger records, per task, its tier, which gates ran, and wall-clock time from claim to merge.

The two Run Wild UI changes that took 40 minutes through implementer and
reviewer seats are the case for solo.

## The solo flow

1. The lead writes `Isolation: solo` on the task at intake.
2. `git switch -c task-N` in its own checkout.
3. A failing focused test at the seam, then the change.
4. The lead runs it and your human partner looks.
5. Merge and delete the branch, ledger tier, gates and wall clock.

## The branch-tier flow

1. `git switch -c task-N` in the lead's checkout, no lane, no worktree, no
   provisioning.
2. One implementer teammate, no isolation, on that branch.
3. Reviewer diffs `<base>..task-N`.
4. The lead merges and deletes the branch, no integrator.
5. `task-created-check` still guards `Files owned`.
