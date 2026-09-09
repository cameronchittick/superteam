# Intent down, exceptions up

Intent goes down; exceptions come up. Downward, a brief carries the goal, the done-criteria and the constraints — never the method. The seat that owns the work owns how the work is done. Upward, a report leads with the answer, written in the audience's vocabulary, shaped as SBAR — situation, background, assessment, recommendation — and only the items that change a decision at the next level cross it unsummarised. Everything else stays where it was produced, reachable by reference: a commit, a file path, a report.

The pattern exists because both directions fail in the same way when register is ignored. A lead that reads diffs stops leading: its context fills with detail it cannot act on, and the decisions it owes the level above go unmade. An IC that reports in domain terms hides the evidence: "the auth work is looking good" gives the lead nothing to check, and the lead cannot tell a passing suite from an optimistic one. Each seat writes in the register of its own audience, and the level boundary does the compression.

## Register table

| Role | Audience | Register | Report shape |
|---|---|---|---|
| ICs: implementer, integrator, researcher, writer, reviewer, skeptic | the team lead (PM) | code specifics: file:line, diff, test output, merge sha | S what changed; B evidence; A verdict/severity; R merge / fix / decision needed |
| team lead (PM) | the lead above or the human | domain terms: user outcome, decisions taken, risks, blockers | done/not done in one line; decisions taken; open decisions for the level above; artifact refs, never diffs |
| lateral (IC↔IC, PM↔PM) | peer | the peer's own vocabulary | free-form with artifact refs |

## Sources

- **Mission command / commander's intent and CCIR (ADP 6-0)** — intent down: the brief states purpose, end state and constraints, and the subordinate chooses the method. CCIR names in advance the exceptions that are worth interrupting a commander for, which is what "only decision-critical items cross a level" means here.
- **SBAR handoff** — the report shape: situation, background, assessment, recommendation, in that order, so the receiver can act on the first line and read the rest only if the recommendation is in doubt.
- **Minto's Pyramid Principle** — answer first: the conclusion leads, supporting evidence follows beneath it, never the reverse.
- **DDD bounded-context language** — lateral talk: two peers meet at a boundary, and the message is written in the receiving context's own vocabulary rather than a shared house style.
- **Anthropic's multi-agent research post, "How we built our multi-agent research system"** — each subagent gets an objective and an output format, and passes lightweight references back rather than raw content.

## The two levers

**ICs — a closing `## Report register` section in each `agents/*.md`.** Output styles apply to the main conversation and its forks only; they never reach subagents or teammates (Claude Code docs, output-styles page, verified 2026-09-09). So an IC's register has to live in the file that defines the seat. Each section names the audience and the register, then maps the report shape the file already defines onto SBAR — it never introduces a second template.

**Team lead — the plugin output style `output-styles/superteam-lead.md`.** Plugin output styles are auto-discovered from `output-styles/`, and this one carries `force-for-plugin: true`, so its text is sent with every request in the lead's session. That is the level that talks to your human partner, and the only level an output style can reach.

## Caveat: force-for-plugin

`force-for-plugin: true` overrides your human partner's own `outputStyle` setting in every session where the plugin is enabled. That is deliberate — the lead register has to hold for the lead's whole session, not only when a style happens to be selected — but it means anyone running Concise would otherwise lose it. So the style carries Concise's core: lead with the result, no preamble, no closing recap, plain prose for simple answers, full detail when detail is asked for, and never trade correctness for brevity. Nothing a Concise session had is lost.

Style files are read at startup. After installing or changing the style, restart Claude Code before expecting it to take effect.
