# Isolation Tiers Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superteam:superteam-driven-development (recommended) or superteam:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace "every task gets a lane and a worktree" with a four-tier isolation rule — solo, branch (default), worktree, provisioned — chosen per task at plan time and written on the task, plus an integration branch only when a plan has two or more tasks merging before trunk; and trim the worktree guard to its three cheap denials.

**Architecture:** One rule table, stated once in a docs page (the SDD skill states the rule in prose and links the page), consumed by the plan template (`**Isolation:**` header line), the task-brief script (emits `Isolation:` and `Branch:` or `Worktree:`), the four agents that act on it, and the guard. Tests assert the rule text exists where the skill says it does and that the script obeys it.

**Tech Stack:** Markdown, bash; `bin/superteam-test`; `claude plugin validate .`

**Spec:** The lead-box brief of 2026-09-09 (Brief A) and the accepted verdicts in `docs/superteam/research/2026-09-09-worktree-cost-assessment.md` (Skeptic verdicts, Default flow, Triggers).

**Integration:** lane/7.4.0 (six tasks merge before trunk).

## Global Constraints

- Voice: "your human partner", never "the user". No new dependencies. Keep other-harness support: fallback-mode text stays, only its isolation becomes conditional.
- Commit trailer: `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>` and `Claude-Session: https://claude.ai/code/session_01W77dwNzwuaSbp6LxsaR7WW`; commit bodies cite `source: <file>#<section>`.
- `bin/superteam-test` 0 failed; `claude plugin validate .` passes.
- **The tier table, verbatim, appears once — in `docs/isolation-tiers.md`:**

```
| Tier | Choose it when | Mechanism | Review | Merge |
|---|---|---|---|---|
| **solo** | the brief is one task, no migration, no money/auth/security/data surface, no other writer active, and the change is small enough for the lead's own context | the lead does it in its own checkout on `task-N`: test-first at the seam, one focused test, commit | no reviewer seat unless the brief asks for one or the diff turns out to touch a listed surface; the lead verifies it running and your human partner looks | the lead: `git merge --no-ff task-N`, `git branch -d task-N` |
| **branch** (default) | where solo ends — a second writer, a required reviewer, or a task too large for the lead to carry — and still one writing seat at a time in this repo | `git switch -c task-N <base>` in the lead's own checkout; the seat is a teammate with no isolation | reviewer diffs `<base>..task-N` | the lead: `git merge --no-ff task-N`, run the suite, `git branch -d task-N`; no integrator seat |
| **worktree** | two or more writing seats must write in this repo at the same time | `EnterWorktree` (teammate) or `isolation: "worktree"` (subagent) — a plain `git worktree add`, nothing provisioned | reviewer diffs `<base>..worktree-task-N-impl` | an integrator seat only when merges are frequent enough to need serialising (three or more worktree-tier tasks in the plan); otherwise the lead merges as in the branch tier |
| **provisioned** | a second running dev server or database is required — a migration under test, a running app for review | the worktree tier plus the repo's own provisioning script, run here and nowhere else | as worktree | as worktree |

`<base>` is the plan's integration branch: trunk by default; a lane branch only when the plan has two or more tasks merging before trunk (the plan header's `**Integration:**` line). The tier is chosen per task at intake — when the plan is written, or when a one-task brief arrives — and travels on the task as its `**Isolation:**` line; a task with no line is branch tier, solo is always written explicitly. A repo that provisions (install, env, database) does it only for the provisioned tier and only from its own script — never on worktree creation.
```

- **Escalation and measurement (verbatim in the docs page and the SDD skill):** `A plan escalates a task from the branch to the worktree tier whenever two or more writing tasks are unblocked at the same time. The lead records in the ledger, per task, the maximum number of concurrent writers, any dirty-checkout collision, and wall-clock time from claim to merge, so the next run of six or more tasks can be judged against the 7.3.0 baseline.`
- **Gates (verbatim in the docs page and the SDD skill):** `Gates scale with what breaks if wrong; they do not run by default. Skeptic: only on a spec or plan that changes a data model or a contract, or that has three or more tasks. Reviewer: only where a slip costs money, auth, security or data, or where the brief asks for one. A UI, copy or docs change your human partner can see for themselves gets neither: the lead verifies it running and your human partner looks. The ledger records, per task, its tier, which gates ran, and wall-clock time from claim to merge.`
- **Branch-tier containment (verbatim in the SDD skill and, its first sentence, in `agents/reviewer.md`):** `The reviewer claims a branch-tier review only after the implement task is complete and judges commits — git diff <base>..task-N — never the working tree. While a branch-tier task is in progress no seat, the lead included, switches branch in the checkout; the guard has no arm for this, the rule and the escalation above are the containment.`
- Rulings from the skeptic pass are in `.superteam/sdd/2026-09-09-isolation-tiers/progress.md`; the provisioned tier stays because Brief A names it and its "here and nowhere else" clause is the point — it costs one table row and one accepted word in `task-brief`, nothing more.
- Terms: "writing seat" = implementer or writer; "integration branch" = trunk or the lane; the four tier words (solo, branch, worktree, provisioned) are lowercase in prose and in the header line.
- Files no task may touch: `skills/using-git-worktrees/SKILL.md`, `hooks/hooks.json`, `hooks/task-created-check`, the three review prompt files, `tests/claude-code/test-worktree-*.sh`, `tests/claude-code/test-sdd-workspace.sh`.

---

### Task 1: Rule page, plan template, README

**Files owned:** `docs/isolation-tiers.md`, `skills/writing-plans/SKILL.md`, `README.md`, `skills/executing-plans/SKILL.md`, `skills/dispatching-parallel-agents/SKILL.md`, `skills/using-superteam/SKILL.md`
**Depends on:** none
**Isolation:** worktree
**Model tier:** standard

- [ ] **Step 1: Create `docs/isolation-tiers.md`** with sections, in order, no others: `# Isolation tiers` (two paragraphs: the rule — isolation is chosen per task at plan time from what the task needs, not applied to every task; and why — the evidence page found the per-task worktree earned its cost only when two or more seats were dirty at once, and Run Wild paid a 2.3 GB install and a database per lane for concurrency that mostly never arrived; link `docs/superteam/research/2026-09-09-worktree-cost-assessment.md`); `## The tiers` (the table from Global Constraints, verbatim, with its trailing paragraph); `## Triggers for the worktree and provisioned tiers` (bullets: two or more writing seats will hold uncommitted work at the same time; the branch will outlive trunk movement and needs rebase-in-place without disturbing the lead's checkout; two dev servers or two databases must run at once — provisioned; enough tasks that a trunk-visible half-done state is unacceptable — integration branch only, still no per-task worktrees); `## Escalation and what the ledger records` (the Escalation and measurement paragraph from Global Constraints, verbatim); `## Gates` (the Gates paragraph from Global Constraints, verbatim, then one sentence: the two Run Wild UI changes that took 40 minutes through implementer and reviewer seats are the case for solo); `## The solo flow` (numbered: 1 the lead writes `Isolation: solo` on the task at intake; 2 `git switch -c task-N` in its own checkout; 3 a failing focused test at the seam, then the change; 4 the lead runs it and your human partner looks; 5 merge and delete the branch, ledger tier, gates and wall clock); `## The branch-tier flow` (numbered: 1 `git switch -c task-N` in the lead's checkout, no lane, no worktree, no provisioning; 2 one implementer teammate, no isolation, on that branch; 3 reviewer diffs `<base>..task-N`; 4 the lead merges and deletes the branch, no integrator; 5 `task-created-check` still guards Files owned).
- [ ] **Step 2: Plan template.** In `skills/writing-plans/SKILL.md`: (a) in the Task Structure template after the `**Model tier:**` line add `**Isolation:** solo | branch | worktree | provisioned` (verbatim); (b) rename the paragraph "**The three header lines.**" to "**The four header lines.**", replace its first sentence "A lead hands each task to an IC in its own worktree, so" with "A lead hands each task to one IC, so", and append this paragraph after it, verbatim:

```
**Isolation: format.** Write `Isolation: solo`, `Isolation: branch`, `Isolation: worktree` or `Isolation: provisioned` — one word, in the header. Branch is the default and what a missing line means: the IC works on `task-N` in the lead's own checkout and the lead merges. Choose solo when the lead can carry the task alone — one task, no migration, no money/auth/security/data surface, no other writer active — and no reviewer is required. Choose worktree only when this task will be written at the same time as another task in the same repo; choose provisioned only when the task needs a second running dev server or database. A plan with two or more tasks merging before trunk names its lane in a header line `**Integration:** lane/<name>`; otherwise `**Integration:** trunk`. The rule and its evidence are in docs/isolation-tiers.md.
```

  (c) In the Plan Document Header block, after the `**Spec:**` line add `**Integration:** trunk | lane/<name> — a lane only when two or more tasks merge before trunk`. (d) In "Self-Review", replace "On demand, or for large plans, dispatch `superteam:skeptic` on the task breakdown (kill / keep / shrink per task) before the plan review;" with "Dispatch `superteam:skeptic` on the task breakdown only when the plan changes a data model or a contract, or has three or more tasks (docs/isolation-tiers.md, Gates);". (e) In "Task subjects on that list" change `step in {implement, review, merge, fix <round>, review <round>}` to `step in {implement, review spec, review standards (both only when the reviewer gate is on), merge (worktree tier only), fix <round>, review <round>}`.
- [ ] **Step 3: README.** Line 291: "Dispatches one implementer IC per task, in its own worktree" → "Dispatches one implementer IC per task, isolated per the task's tier (branch by default)". Lines 341 and 345: "in an isolated worktree" → "on its own branch, in a worktree only when the task's tier says so". Line 346: "removes the worktree" → "removes the worktree when there was one". In the bash-guard block (lines ~395–406): delete the sentence "It reads the command as text rather than running it — `cd /tmp && rm -rf ./x` reads as a relative target and a symlink out of the worktree is not resolved — so it is a guardrail against the common destructive typo, not a sandbox." and any mention of `rm -rf`; state the three denials by name (tmux kill-server, `git checkout .`, `git reset --hard`) and that it "is a guardrail against three destructive typos, not a sandbox". Under `### Agents`, after the existing register sentence, add: `Where each task runs — the lead alone, an IC on the lead's own branch, a worktree, or a provisioned lane — and which gates (skeptic, reviewer) run are chosen per task at intake by what breaks if the task is wrong; see [docs/isolation-tiers.md](docs/isolation-tiers.md).`
- [ ] **Step 3b: Three skills that still say every writer gets a worktree.** `skills/executing-plans/SKILL.md:19` "Ensure an isolated workspace: use superteam:using-git-worktrees" → "Work on a task branch in this checkout; use superteam:using-git-worktrees only when another writer is active in the same repo (docs/isolation-tiers.md)". `skills/dispatching-parallel-agents/SKILL.md:81` — the `isolation: "worktree"` line keeps its value (parallel implementers are, by definition, two or more writing seats at once) and gains the comment `# parallel writers = worktree tier; see docs/isolation-tiers.md`. `skills/using-superteam/SKILL.md:28` "(`isolation: worktree` when it edits)" → "(`isolation: worktree` only when it edits while another writer is active)". No other line in those files changes.
- [ ] **Step 4: Verify** `claude plugin validate .`; `grep -c 'Isolation' skills/writing-plans/SKILL.md` ≥ 3; `grep -c 'rm -rf' README.md` prints 0; `grep -c 'isolation-tiers' skills/executing-plans/SKILL.md skills/dispatching-parallel-agents/SKILL.md` each ≥ 1.
- [ ] **Step 5: Commit** "Isolation tiers: rule page, plan header line, README" with `source: docs/isolation-tiers.md`.

---

### Task 2: SDD skill, implementer prompt, task-brief

**Files owned:** `skills/superteam-driven-development/SKILL.md`, `skills/superteam-driven-development/implementer-prompt.md`, `skills/superteam-driven-development/re-review-prompt.md`, `skills/superteam-driven-development/scripts/task-brief`, `tests/claude-code/test-dispatch-template.sh`
**Depends on:** none
**Isolation:** worktree
**Model tier:** most capable

- [ ] **Step 1: New section `## Isolation tiers`** in `SKILL.md`, placed immediately before `## Two kinds of IC`, no table: one paragraph — "Every task carries an `**Isolation:**` line chosen at intake. **solo**: the lead does the task itself in its own checkout — one task, no migration, no money/auth/security/data surface, no other writer active, small enough for its own context; no implementer, no reviewer unless the brief asks. **branch** (the default, and what a missing line means): where solo ends — a second writer, a required reviewer, or a task too large for the lead — one writing seat at a time in this repo, on `task-N` in the lead's own checkout, the lead merges. **worktree**: two or more writing seats must write in this repo at once; a plain `git worktree add`, nothing provisioned. **provisioned**: the worktree tier plus the repo's own provisioning script, only when a second running dev server or database is required. `<base>` is trunk, or the lane the plan header names in `**Integration:**`. The table, triggers and evidence are in docs/isolation-tiers.md." — then the Escalation and measurement paragraph, the Gates paragraph and the Branch-tier containment paragraph from Global Constraints, each verbatim, as their own paragraphs.
- [ ] **Step 2: Retire the universal-worktree sentences**, each edit named:
  - frontmatter `description` (line 3): "one implementer IC per task in its own worktree" → "one implementer IC per task, isolated per the task's tier".
  - Intro (lines 8–14) and the "What this adds" bullet (59–65): "in its own worktree" → "on its own branch, in a worktree only when its tier says so"; drop "(no context pollution, no file collisions)" and write "(a fresh context per IC; file collisions are refused by the task-created-check hook)".
  - `## Two kinds of IC`, writing-seat paragraphs (87–115): replace with — branch tier: the seat claims, runs `git switch -c <Branch> <Lane>` in the lead's checkout, commits on that branch and stays on it, reports; the lead merges; while a branch-tier task is in_progress no one, the lead included, changes branch in that checkout. Worktree/provisioned tier: as today (EnterWorktree, `git merge <lane>` first, integrator or lead merges). Keep the split-pane warning but scope it: "Split panes are required when any task in the plan is worktree tier". Keep the "never an absolute path into the checkout" paragraph scoped to worktree seats; a branch-tier seat reads the plan's committed path directly.
  - Integrator paragraph (136–140): "dispatched only when the graph has merge tasks — worktree-tier tasks in a plan with three or more of them; otherwise the lead merges in "5. Complete the task"".
  - Process graph (148–215): change the implementer node label to "implementer self-claims, isolates per tier (branch: git switch -c; worktree: EnterWorktree + git merge lane)" and the merge node to "lead (branch tier) or integrator (worktree tier) merges the branch into <base>". Keep the dot syntax valid (`dot` is absent on this host; check with `grep -c '\->'` unchanged ±2 and balanced braces).
  - `## Modes` (217–232): "Team mode also requires split-pane teammates" → "Team mode requires split-pane teammates whenever a task is worktree tier"; keep the dogfood sentence.
  - `## Setup` (234–242): replace the first paragraph with: the integration branch is trunk unless the plan header says `**Integration:** lane/<name>`; create the lane only then (via superteam:using-git-worktrees when the lead itself needs isolation, otherwise `git switch -c`); branch-tier seats branch from `<base>` in the lead's checkout; worktree seats branch from the default branch and `git merge <base>` first. Keep "Never start implementation on a main/master branch without your human partner's explicit consent" — a branch-tier task branch is not main.
  - Sentence at 249–256 about worktree implementers and the workspace path: prefix "A worktree-tier implementer".
  - `## Task graph`: table — the merge row gains "(worktree tier only, when an integrator seat exists; otherwise the lead merges after both reviews)"; the description block shows `Isolation: branch` + `Branch: task-N` for branch tier and `Isolation: worktree|provisioned` + the existing `Worktree:` line otherwise; `Reviews:` names whichever branch. The exact-calls block: the `merge` call is annotated "worktree tier with an integrator only". Add one sentence: "A branch-tier family has three tasks; the review completing is the lead's cue to merge."
  - **Gates in the graph.** The per-task `review spec` / `review standards` tasks, the fix-round loop and the final two-axis review (`superteam:requesting-code-review`) are created only when the reviewer gate is on for that task or plan (money, auth, security, data, or the brief asks); otherwise the implementer's report plus the suite is the gate and the lead merges. Name this in the process graph (a `Reviewer gate on?` diamond before the review node, its `no` edge going to the merge node), in `## Task graph` ("a gated-off task's family is implement, then merge or the lead's merge"), in `## The Process` intro, and in `## Finish` ("the final review runs only when the reviewer gate is on for the plan"). The skeptic pre-scan in `## Setup` stays the lead's own conflict table; `superteam:skeptic` is dispatched from writing-plans under its own gate, never from this skill. The ledger's per-task line records `tier`, `gates: none | reviewer | skeptic+reviewer`, wall clock.
  - `## Role pool`: sizing → "1 writing seat; a reviewer only when some task's reviewer gate is on; add one writing seat per concurrent worktree-tier task; an integrator only when the plan has three or more worktree-tier merges; at most 5 teammates".
  - `### 1. Dispatch the implementer` fallback block: `isolation: "worktree"` line annotated `# worktree/provisioned tier only; omit for branch tier`; the BASE-per-branch note holds for both.
  - `### 2. Handle the report` (616–620): copy-out sentence prefixed "Worktree tier:".
  - `### 5. Complete the task`: add, before the integrator dispatch, a **Branch tier** paragraph: `git switch <base>`, `git merge --no-ff task-N` with the commit trailer, run the full suite, `git branch -d task-N`, record the merge sha in the ledger; then "Worktree tier:" before the existing integrator text.
  - `## Finish`: "merge the lane into trunk" → "merge the lane into trunk when the plan used one".
  - `## Example Workflow`: add a second, five-line example at the end: a one-task plan, branch tier, three tasks on the list, lead merges.
- [ ] **Step 3: implementer-prompt.md.** Line 12 `isolation: "worktree"` gets the comment `# worktree/provisioned tier only; omit for branch tier`. `## Paths` first sentence → "All paths are relative to your cwd — your worktree on the worktree tier, the lead's checkout on the branch tier." Keep the absolute-path rule for worktree seats.
- [ ] **Step 4: task-brief.** In `--taskcreate`: read `iso=$(printf '%s\n' "$brief" | sed -n 's/^\*\*Isolation:\*\*[[:space:]]*//p' | head -1 | tr -d '`')`, default `branch`; reject any value other than solo/branch/worktree/provisioned with exit 5 and a message. `solo` behaves as `branch` in every emitted line, with `Branch: task-${n}        (the lead works it in its own checkout)`. Emit, after the `Lane:` line, `Isolation: ${iso}`; then for branch tier `Branch: task-${n}        (git switch -c in the lead's checkout, from Lane)` and no `Worktree:` line; for the other tiers the existing `Worktree:` line. `Reviews:` prints `task-${n}` on branch tier, `worktree-${wt}` otherwise. `merge` kind on branch tier: print `branch tier has no merge task; the lead merges task-${n}` to stderr, exit 4. The merge kind's `Merge:`/`Done:` lines keep `worktree-${wt}` for the other tiers.  `provisioned` is accepted and handled exactly as `worktree`.
- [ ] **Step 5: test-dispatch-template.sh** (c2 block): the fixture `plan.md` gets a second task with `**Isolation:** worktree`; assert for task 1 (no Isolation line): `^Isolation: branch$`, `^Branch: task-1`, and NOT `^Worktree:`; `review-spec` for task 1 has `^Reviews: task-1$`; `merge` for task 1 exits non-zero; for task 2: `^Isolation: worktree$`, `^Worktree: task-2-impl`, review `^Reviews: worktree-task-2-impl$`, merge `^Merge: worktree-task-2-impl → lane/x$`. The three existing task-1 assertions that expect the worktree name (`:104` `^Worktree: task-1-impl`, `:111` `Reviews: worktree-task-1-impl`, `:115` the `Merge:` line) are rewritten to the task-1 expectations above, not kept; every other assertion stays.
- [ ] **Step 5a: solo in the fixture.** `test-dispatch-template.sh` fixture gets a third task with `**Isolation:** solo`; assert `^Isolation: solo$`, `^Branch: task-3`, no `^Worktree:`; and that `**Isolation:** lane` exits 5.
- [ ] **Step 5b: re-review-prompt.md** lines 46 and 132: the report-was-copied-out-of-the-worktree wording gains "(worktree tier; on the branch tier the report is already in the checkout)". Nothing else in the file changes.
- [ ] **Step 5c: Ledger metrics.** In `## Setup` ledger bullets add one: "Per task, the ledger records wall-clock time from claim to merge, the maximum number of writing seats active at once, and any dirty-checkout collision (a seat finding uncommitted changes it did not make) — the measurement the Escalation paragraph promises." In `### 5. Complete the task` the branch-tier paragraph ends "…record the merge sha, wall clock and concurrent-writer count in the ledger".
- [ ] **Step 6: Verify** `bash tests/claude-code/test-dispatch-template.sh` PASS; `bash bin/superteam-test` 0 failed; `claude plugin validate .`.
- [ ] **Step 7: Commit** "SDD: isolation tiers — branch by default, worktree on demand, integrator only when merges need serialising" with `source: skills/superteam-driven-development/SKILL.md#isolation-tiers`.

---

### Task 3: Agents and the finish skill

**Files owned:** `agents/implementer.md`, `agents/writer.md`, `agents/integrator.md`, `agents/reviewer.md`, `skills/finishing-a-development-branch/SKILL.md`, `tests/claude-code/test-agent-roster.sh`
**Depends on:** none
**Isolation:** worktree
**Model tier:** standard

- [ ] **Step 1: implementer.md and writer.md, `## Isolating (teammate)`** — keep the heading; replace the first paragraph with, verbatim:

```
Your task's `Isolation:` line says where you work. **branch** (or no line): stay in the lead's checkout, `git switch -c <Branch> <Lane>` using the description's `Branch:` and `Lane:` values, and do every edit, test and commit on that branch; never switch away from it while the task is in progress, and leave it checked out when you complete — the lead merges it. **worktree** or **provisioned**: `EnterWorktree` with the `Worktree:` name from the description, and the first command inside it is `git merge <Lane>` so you build on the tasks already merged. Do every edit, test and commit there. Before completing the task, `ExitWorktree` keeping the worktree — whoever merges removes it. As a subagent on those tiers you already have `isolation: worktree`; skip this section.
```

  Numbered item 4 ("Paths: everything is relative to your cwd, which is your worktree...") → "Paths: everything is relative to your cwd — the lead's checkout on the branch tier, your worktree otherwise. Never use an absolute path into the main checkout from a worktree; never `cd` out of it." Item 5(g): "Commit on your worktree branch" → "Commit on your task branch"; "Never touch anything outside your worktree" → "Never touch a file outside `Files owned:`". `## Worktree guard: known refusals`: prefix the first sentence with "On the worktree tier," . `## Report`: any "outside your worktree" → "outside `Files owned:`".
- [ ] **Step 2: integrator.md.** After the first paragraph add, verbatim: "You exist only when the task graph has merge tasks — worktree-tier tasks in a plan with three or more of them. On the branch tier, and on small worktree plans, the lead merges and you are not spawned." In `## Merging from the list` the `git worktree remove` step gets "(skip when the branch has no worktree)".
- [ ] **Step 3: reviewer.md (lines 31–34).** "The description's `Reviews: worktree-task-N-impl` names the branch to judge" → "The description's `Reviews:` line names the branch to judge — `task-N` on the branch tier, `worktree-task-N-impl` otherwise"; the diff command → `git diff <Lane>..<that branch>`. Add, verbatim, the first sentence of the Branch-tier containment paragraph from Global Constraints. Keep "never enter the worktree".
- [ ] **Step 4: finishing-a-development-branch.md, Team teardown.** "Once every task's merge is done, merge the lane branch into trunk" → "Once every task's merge is done, merge the lane branch into trunk if the plan used one (`**Integration:** lane/...`); a trunk-integrated plan has nothing left to merge".
- [ ] **Step 5: test-agent-roster.sh (lines 153–159).** Keep the three greps (they still match: the tools line, the heading, the phrase "first command inside it is `git merge"). Add one per role inside the two-role loop at line 156 (`for role in implementer writer`), not the six-role loop at 145: `grep -q 'git switch -c <Branch> <Lane>' "$AGENTS/$role.md"` → pass/fail "agents/$role.md has the branch-tier path".
- [ ] **Step 6: Verify** `bash tests/claude-code/test-agent-roster.sh` PASS; `claude plugin validate .`.
- [ ] **Step 7: Commit** "Agents: branch tier by default; integrator only when merges need serialising; reviewer diffs the named branch" with `source: agents/implementer.md#isolating-teammate`.

---

### Task 4: Guard keeps three denials

**Files owned:** `hooks/bash-guard`, `tests/hooks/test-bash-guard.sh`
**Depends on:** none
**Isolation:** worktree
**Model tier:** cheap

- [ ] **Step 1: bash-guard.** Header: "Denies four Bash commands" → "Denies three Bash commands"; delete the `rm -rf <path outside $PWD>` line; in the blind-spots paragraph delete the two sentences about `cd /tmp && rm -rf ./x` and the symlink/`$PWD` prefix; keep the backtick and line-start sentences. `usage()`: drop ", and rm -rf aimed at a path outside the current worktree ($PWD)". Delete everything from the comment `# rm -rf: walk the tokens` through the `deny "rm -rf ..."` block (the `check_target` function, the `set -f` walk, `set +f`, the final `if [ -n "$outside_target" ]`), leaving the three denials and `exit 0`.
- [ ] **Step 2: test-bash-guard.sh.** Header echo "the four denied commands" → "the three denied commands". Delete the sections "rm -rf outside the worktree" and "rm -rf inside the worktree is allowed" and the two rm lines under "quoted in text" (`a dotted file name`, `a leading ../ still escapes`). The escape-hatch loop drops `"rm -rf ~/x"`. Every remaining payload that used `rm -rf` (the Edit-tool scope check, the `SUPERTEAM_SKIP_VERIFY_GATE=1` bypass, the malformed-JSON and quoted-path cases) is re-based on `git reset --hard` so the coverage survives; a case that only made sense for path containment is deleted. Add `assert_allowed "rm -rf outside PWD is no longer the guard's business" "rm -rf ../other"`.
- [ ] **Step 3: Verify** `bash tests/hooks/test-bash-guard.sh` PASS; `grep -c check_target hooks/bash-guard` prints 0.
- [ ] **Step 4: Commit** "bash-guard: keep the three denials, drop the rm -rf containment arm" with `source: hooks/bash-guard#header`.

---

### Task 5: Tests for the rule text

**Files owned:** `tests/claude-code/test-isolation-tiers.sh`, `bin/superteam-test`, `tests/claude-code/test-superteam-driven-development.sh`
**Depends on:** Task 1, Task 2, Task 3, Task 4
**Isolation:** branch
**Model tier:** cheap

- [ ] **Step 1: `tests/claude-code/test-isolation-tiers.sh`** (roster-test style, `set -uo pipefail`, own pass/fail, non-zero exit on any fail), asserting only what no other test covers — the rule text: `docs/isolation-tiers.md` exists and has `^## The tiers`, `^## Escalation and what the ledger records`, `^## Gates`, `^## The solo flow` and `^## The branch-tier flow` (no `one-task flow` heading); its table has the four row labels `| **solo** |`, `| **branch** (default) |`, `| **worktree** |`, `| **provisioned** |`; `skills/superteam-driven-development/SKILL.md` has `^## Isolation tiers`, the phrase `two or more writing tasks are unblocked at the same time` and the phrase `they do not run by default`; `skills/writing-plans/SKILL.md` has `three or more tasks`; `skills/writing-plans/SKILL.md` has `^\*\*Isolation:\*\* solo | branch | worktree | provisioned$`; `README.md`, `skills/executing-plans/SKILL.md` and `skills/using-superteam/SKILL.md` each mention `isolation-tiers`; `agents/reviewer.md` contains `never the working tree`. Task-brief behaviour, the agents' branch-tier line and the guard's arms are asserted by the tests Tasks 2–4 own; do not repeat them here.
- [ ] **Step 2: Runner row** `tests/claude-code/test-isolation-tiers.sh|` after the output-style row in `bin/superteam-test`.
- [ ] **Step 3: test-superteam-driven-development.sh Test 8** (live `claude -p`, excluded from the runner): rename to "Isolation rule" and expect `"isolation\|tier\|branch\|worktree"`.
- [ ] **Step 4: Verify** `bash tests/claude-code/test-isolation-tiers.sh` PASS; `bash bin/superteam-test` 0 failed.
- [ ] **Step 5: Commit** "Tests: isolation tier rule text and task-brief behaviour" with `source: tests/claude-code/test-isolation-tiers.sh`.

---

### Task 6: Bump (lead)

**Files owned:** the nine version manifests
**Depends on:** Task 1, Task 2, Task 3, Task 4, Task 5
**Isolation:** branch
Bump 7.3.0 → 7.4.0 (behaviour change: isolation tiers and gates); `bin/superteam-test`; `claude plugin validate .`; merge lane/7.4.0 into main.
