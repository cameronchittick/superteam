# Design It Twice

When your human partner wants to explore alternative interfaces for a chosen deepening candidate, use this parallel design-agent pattern. Based on "Design It Twice" (Ousterhout) — your first idea is unlikely to be the best.

Uses the vocabulary in [SKILL.md](SKILL.md) — **module**, **interface**, **seam**, **adapter**, **leverage**.

## Process

### 1. Frame the problem space

Before dispatching the design agents, write a human-partner-facing explanation of the problem space for the chosen candidate:

- The constraints any new interface would need to satisfy
- The dependencies it would rely on, and which category they fall into (see [DEEPENING.md](DEEPENING.md))
- A rough illustrative code sketch to ground the constraints — not a proposal, just a way to make the constraints concrete

Show this to your human partner, then immediately proceed to Step 2. Your human partner reads and thinks while the design agents work in parallel.

### 2. Dispatch design agents

Dispatch 3+ design agents in parallel per superteam:dispatching-parallel-agents — each is `superteam:researcher`: one brief, one constraint each, all in one message, no worktree (a researcher never edits an existing file and may create exactly one findings file per task, `docs/superteam/research/<date>-<slug>.md`). Each must produce a **radically different** interface for the deepened module.

Prompt each design agent with a separate technical brief (file paths, coupling details, dependency category from [DEEPENING.md](DEEPENING.md), what sits behind the seam). The brief is independent of the human-partner-facing problem-space explanation in Step 1. Give each agent a different design constraint:

- Agent 1: "Minimize the interface — aim for 1–3 entry points max. Maximise leverage per entry point."
- Agent 2: "Maximise flexibility — support many use cases and extension."
- Agent 3: "Optimise for the most common caller — make the default case trivial."
- Agent 4 (if applicable): "Design around ports & adapters for cross-seam dependencies."

Include both [SKILL.md](SKILL.md) vocabulary and CONTEXT.md vocabulary in the brief so each design agent names things consistently with the architecture language and the project's domain language.

Each design agent outputs:

1. Interface (types, methods, params — plus invariants, ordering, error modes)
2. Usage example showing how callers use it
3. What the implementation hides behind the seam
4. Dependency strategy and adapters (see [DEEPENING.md](DEEPENING.md))
5. Trade-offs — where leverage is high, where it's thin

### 3. Present and compare

Present designs sequentially so your human partner can absorb each one, then compare them in prose. Contrast by **depth** (leverage at the interface), **locality** (where change concentrates), and **seam placement**; then offer `superteam:skeptic` on the comparison before recommending.

After comparing, give your own recommendation: which design you think is strongest and why. If elements from different designs would combine well, propose a hybrid. Be opinionated — your human partner wants a strong read, not a menu.
