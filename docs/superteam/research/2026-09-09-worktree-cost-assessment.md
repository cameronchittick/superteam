# Worktree/branch/lane cost assessment

## Conclusion

The numbers show the worktree layer earns its cost in superteam-driven-development itself — real concurrent implementers and writers ran in separate worktrees on the same task graph with zero merge conflicts recorded — but that evidence does not transfer to Run Wild, where the ledgers show mostly one task in flight at a time yet every task still pays a ~2.3GB `npm ci` and a full DB migrate+seed on worktree creation. The cheaper mechanisms (Files-owned non-overlap, already enforced by `task-created-check` independent of worktrees; a branch in the PM's own checkout; `git stash`) cover cases (a) PM/implementer collision and (c) reviewer diffing without a worktree at all, so a small single-lane UI fix does not need the full per-lane install. Worktrees are earning their keep specifically where two+ writers are provably concurrent in the same repo (superteam's dogfood runs) or where a lane runs long enough to need rebasing against a moving trunk (11 such rebases in Run Wild since 2026-09-05); outside those conditions the per-lane provisioning cost (disk + npm ci + DB create/migrate/seed) is unmeasured in time but concretely 2.3GB per lane in disk, paid whether or not concurrency happens.

## Usage table (since 2026-09-05)

| Repo | SDD ledgers | Task merges (git log) | Concurrent-in-repo evidence | Real conflicts | Lanes holding >1 task |
|---|---|---|---|---|---|
| superteam | 2 found (lead said 3; only `.superteam/sdd/2026-09-05-universal-agent-team-system/progress.md` and `.superteam/sdd/2026-09-09-report-register/progress.md` exist — `fixture-plan/` has no progress.md) | 48 task merges (55 total merges minus 5 lane merges minus 2 trunk-into-worktree rebase merges) | Yes — ledger: "22:24:17 graph created... Pool: impl-1 opus, writer-1 sonnet, writer-2 opus"; claims 19–36s apart on tasks #5/#9/#8 while all three worked simultaneously in separate worktrees (`.superteam/sdd/2026-09-05-.../progress.md`); 7.3.0 run had tasks 23–26 running as parallel writer/implementer pairs | 0 found — no `conflict` in any merge body since 2026-09-05, and the one ledger "conflict" hit (line 6) is a pre-flight file-name check, not a merge conflict | Not observed — worktree branches are one task each (`worktree-task-N-impl` naming, `git worktree list` shows exactly one live task branch: `task-3-impl`) |
| runwild | 1 found: `.superteam/sdd/2026-09-09-chat-panel-loading/task-111-report.md` (a report, not a wave ledger — no progress.md with pre-flight/concurrency notes exists) | 61 `merge: Task` / `merge:` subjects since 2026-09-05 (of 114 total merges; 8 are GitHub PR merges, 11 are trunk-into-lane rebases, `into wt/agent-*` merges make up the rest) | Unmeasured directly (no wave notes); 2 `wt/agent-*` worktrees are live right now simultaneously (`git worktree list`), each with its own DB (`runwild_wt_agent_*`), so the machinery is provisioned for concurrency even when tasks in a plan (e.g. front-desk-fold, 12 tasks in ~8 hours on 09-08/09) look sequential by commit timestamp | 1 of 61 (`edf59ddc`: "# Conflicts:\n#\tlib/mastra/workflows/index.ts") ≈ 1.6% | Unmeasured — branch names are task-scoped (`wt/task-N`) or per-agent-session (`wt/agent-<hash>`); no ledger records multiple tasks reusing one lane |
| marketing | `sdd/` dir exists but no progress.md checked in detail | 6 "Task N" merges, all on 2026-09-05, no `scripts/worktree/` in this repo (no per-lane install/DB layer at all) | Unmeasured | 1 merge subject literally reads "Task 1, conflict fixes" (unclear if a real git conflict or a code fix named "conflict") | Unmeasured |
| soluma, luxurycharters, prospecting, claude-trade | none | 0 task/worktree/lane merges since 2026-09-05 | n/a | n/a | n/a |

## Cost table

| Repo | Worktree mechanism | Steps on creation | Measured cost |
|---|---|---|---|
| superteam | `EnterWorktree`/`isolation:worktree`, bare git worktree, gitignored `.superteam/` copied in by the lead | `git worktree add` only — no install/DB step (skill: "For superteam, note that the worktree is bare git", per lead's brief; confirmed no `scripts/worktree/` install/DB script exists in this repo) | Near-free; `git worktree add` itself is a fast, local metadata operation. No timing recorded because there's nothing slow to time. |
| runwild | `create-worktree.sh` (42 lines) → `setup-worktree.sh` (270 lines) | 1) lowest free port scan 3001–3099 (`setup-worktree.sh:139-177`); 2) generate `.env` from main's, rewriting `DATABASE_URL`/`PORT` (`:180-220`); 3) real `npm ci`, never symlinked — Turbopack rejects symlinks (`:222-235`, comment: "this is the slow part; runs once per worktree"); 4) shared Postgres container, private DB per worktree: `createdb`, `npm run db:migrate`, seed script (`:237-264`) | Time unmeasured (not logged by the script, no ledger records it, and running it to time it would violate the read-only/no-new-worktree constraint). Disk measured directly: `du -sh .claude/worktrees/*/node_modules` = 2.3G per live lane (2 lanes = 4.6G duplicate, on top of 2.3G in the main checkout = 6.9G total for 160 declared deps in `package.json`). Two separate live databases confirmed: `runwild_wt_agent_ad82775fe09916ae8`, `runwild_wt_agent_a67c0df2f45d51e8f` (`docker exec runwild-postgres-1 psql ... pg_database`). |

## Layers table

| Layer | Protects against | Cheaper mechanism | Where it fails |
|---|---|---|---|
| Worktree per task (superteam, bare git) | (a) PM and implementer editing the same checkout; (b) two implementers colliding on files | A branch in the PM's own checkout + `git stash` before switching; `task-created-check` already rejects a task whose `Files owned:` overlaps an open task with no `Depends on:` edge (`hooks/task-created-check:24-25,101-107`) | Two implementers genuinely running in parallel in one repo still need two live checkouts to both have uncommitted work at once — a single checkout with stash can't hold two agents' dirty trees simultaneously. The dogfood ledger shows exactly this case happening (3 seats concurrently, 09-05). |
| Worktree per task (runwild, provisioned) | (a)+(b) above, plus DB/port collision between two running dev servers | Files-owned non-overlap for (a)/(b); for the DB/port collision specifically, nothing cheaper exists once two dev servers must run simultaneously — that's inherent to Next.js dev server + Postgres, not a worktree-driven cost | A single small UI fix with nothing else in flight never needs a second dev server or DB at all — the provisioning cost (npm ci, migrate, seed) is paid regardless of whether concurrency ever materializes. |
| Stable diff for reviewer | (c) reviewer needing a diff that doesn't move under it while reviewing | Reviewer diffs a commit range (`git diff <base>..<branch>`) or a specific SHA — this works whether the branch lives in a worktree or the PM's own checkout, since the branch itself (not the worktree) is what's stable | Only fails if the PM's checkout is also being edited live by someone else while the reviewer diffs — i.e., collapses back into case (a). |
| Mergeable unit for integrator | (d) integrator needing something to merge and then delete cleanly | A branch (any checkout) is sufficient — `git merge <branch>` doesn't require the branch to have lived in a worktree. Worktree adds "remove the worktree" as an extra teardown step (`remove-worktree.sh`, `stop-lane.sh`) | No case found where the integrator's job specifically requires a worktree rather than a bare branch — the worktree exists upstream of the integrator, for the implementer's benefit. |

## Required cases

- **Parallel implementers/writers in one repo** — the only case with direct evidence of necessity: superteam's 2026-09-05 dogfood ledger shows 3 seats (impl-1, writer-1, writer-2) committing to separate worktree branches within a 36-second claim window; a single checkout could not have held all three's uncommitted state at once.
- **Lane outliving the trunk** — runwild has 11 "Merge branch '...' into wt/..." rebase merges since 2026-09-05, meaning lanes stayed open long enough that trunk moved under them; a worktree survives that without disturbing the PM's own checkout.
- **Schema migrations / long tasks alongside hotfixes** — asserted by the brief as a candidate; not directly evidenced in the sampled ledgers (front-desk-fold's migration task, Task 1, merged same-day as the rest, not alongside a hotfix) — **unmeasured**, would need a case where a migration lane and a hotfix lane were both open at once.

## Evidence

- `.superteam/sdd/2026-09-05-universal-agent-team-system/progress.md` (superteam) — concurrency notes quoted above.
- `.superteam/sdd/2026-09-09-report-register/progress.md` (superteam) — Task 23–26 parallel writer/implementer graph.
- `.superteam/sdd/fixture-plan/` (superteam) — exists, contains only `standards`, no `progress.md`.
- `hooks/task-created-check:7,24-25,75-76,95,101-107` (superteam) — Files-owned overlap enforcement, independent of worktrees.
- `skills/superteam-driven-development/SKILL.md:61-63` — "Fresh IC per task, each in its own worktree (no context pollution, no file collisions)".
- `agents/implementer.md:26-31,82-87` — EnterWorktree/ExitWorktree and worktree-guard command restrictions.
- `scripts/worktree/setup-worktree.sh:1-270` (runwild) — 4-step provisioning (port, env, npm ci, Postgres/migrate/seed); "this is the slow part" comment at line 231.
- `scripts/worktree/create-worktree.sh:1-43` (runwild) — WorktreeCreate hook wrapper.
- `git log --all --merges --since=2026-09-05` (both repos, commands run above) — merge counts.
- `git show -s --format='%B' edf59ddc` (runwild) — the one real merge conflict found.
- `du -sh .claude/worktrees/*/node_modules`, `docker exec runwild-postgres-1 psql ...` (runwild) — live disk/DB numbers.

## Open

- **runwild npm ci / migrate / seed wall-clock time** — not logged anywhere read-only-accessible; would need either instrumenting `setup-worktree.sh` with timestamps on a real run, or checking CI logs (not fetched here — `gh` was not used since no PR/Actions log was pulled).
- **Third superteam ledger** the lead expected — only 2 found; either it was pruned, lives in a worktree that's since been removed, or the lead's count included `fixture-plan/` (which has no `progress.md`). Worth confirming with the lead.
- **Migration-alongside-hotfix case** — asserted as a required case in the brief but not directly evidenced in the sampled history; would need a ledger or commit-timestamp overlap showing both open at once.

## Skeptic verdicts (superteam:skeptic, 2026-09-09)

1. **shrink — lane branches.** Earns its keep only when a plan has 2+ tasks merging before trunk (superteam: 48 task merges under 5 lane merges; runwild: 11 trunk-into-lane rebases). For one task it is two merges to move one commit, and SKILL.md's mandatory `git merge <lane>` first step is the lane's own cost paid back task by task.
2. **shrink — per-task worktrees.** Necessity is evidenced in one shape only: 2+ writing seats dirty at the same instant (3 seats claiming within 36 s). File collisions are already covered by `hooks/task-created-check` (Files-owned overlap rejection, worktree-independent), reviewer stability by a commit range, integrator mergeability by a bare branch. Context isolation comes from the fresh IC, not the worktree. Sized for the 3-writer case and charged to every task.
3. **shrink — per-lane DBs and installs (Run Wild).** `setup-worktree.sh:222-264` runs `npm ci` and createdb+migrate+seed on every lane unconditionally: 2.3 GB per lane, 6.9 GB live now. The only thing that cannot be shared is a second *running* dev server's port and DB; provisioning should be coupled to "a second dev server is about to run", not to worktree creation.
4. **shrink — the integrator seat.** Middle Man: five fixed commands, every judgment bounced back to the lead. It buys serialization and keeps suite output out of the lead's context, which matters only when merges are frequent.
5. **shrink — the worktree guard.** Keep the three cheap denials (tmux kill-server, `git checkout .`, `git reset --hard`). Cut the `rm -rf` containment arm: Bash-only so Write/Edit bypass it, a literal `$PWD` prefix compare that misses `cd /tmp && rm -rf ./x` and symlinks, and a false positive on report prose starting with `git reset --hard`. It advertises isolation it cannot deliver.

**Default flow, one small fix, nothing else in flight:**
1. Branch in the lead's own checkout (`git switch -c fix/<thing>`); no lane, no worktree, no provisioning.
2. One implementer subagent, no isolation, on that branch.
3. Reviewer diffs `main..fix/<thing>`.
4. Lead merges and deletes the branch; no integrator, no teardown.
5. `task-created-check` still guards file ownership if the list is used.

**Triggers for the full lane/worktree path (any one):**
- Two or more writing seats will hold uncommitted work at the same time (the only directly evidenced case).
- The branch will outlive trunk movement and need rebase-in-place.
- Two dev servers / two DBs must run at once — this, not worktree creation, should trigger Run Wild's provisioning.
- Enough tasks that a trunk-visible half-done state is unacceptable (lane only; still no per-task worktrees).
- Unmeasured: migration lane alongside a hotfix — not a trigger until observed.

**Cut this first:** Run Wild's unconditional `npm ci` + createdb/migrate/seed in `setup-worktree.sh:222-264`.
