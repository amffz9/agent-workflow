---
name: "prompting-opus-5"
description: Use when writing a prompt, subagent brief, system prompt, agent definition or standing instructions that Claude Opus 5 pinned as claude-opus-5 will execute, when choosing Opus 5 effort or thinking settings, or when migrating prompts written for Opus 4.x. In Claude Code 2.1.280+ the "opus" alias runs Opus 5.5 instead; use prompting-opus-5-5 for that.
---

# Prompting Claude Opus 5

For pinned `claude-opus-5` only; `model: opus` now runs Opus 5.5
(`prompting-opus-5-5`). Opus 5 verifies its own work and reviews well, so most
of the work is removing habits older models needed.

## Tendencies and what to write

| Opus 5 by default | Write this |
|---|---|
| Long responses; lowering effort doesn't shorten them. | State the length you want, with a positive example. |
| Long written deliverables. | Size the document to the task; no filler sections or repeated summaries. Give a cap if you have one. |
| Narrates often during agentic work. | One sentence before the first tool call, updates only on findings or a change of direction, outcome first at the end. |
| Widens scope. | "Deliver what was asked, at the scope intended." Make routine judgment calls; check in only when readings differ materially. |
| Self-checks unprompted. | Delete "double-check", "final verification step" and "use a subagent to verify". They add tokens, not quality. |
| Delegates readily. | Delegate only large, truly independent parallel work; one agent when one is enough. |
| Narrates corrections to itself. | Correct aloud only when the error changes the user's code, conclusions or decisions. |
| Follows conservative review wording literally. | Ask for every finding with severity and confidence; filter afterwards. |
| Literal: "suggest changes" gets suggestions. | Use the verb you mean: "change X" or "recommend, don't edit". |

## Settings

- **Effort:** `low`, `medium`, `high` (default), `xhigh`, `max`. Start at
  `high`; `xhigh` for demanding agentic coding. `low` and `medium` hold quality
  well, including for review. Effort controls thinking, not visible length.
- **Thinking** is adaptive and on by default; it can be disabled only at `high`
  or below. Prefer `low` effort with thinking over thinking off.
- **API:** give `max_tokens` headroom at `xhigh`/`max` (start around 64k).
  Sampling parameters and prefill return 400s.
- **Price:** $5 / $25 per 1M tokens.
- **Claude Code:** `model: claude-opus-5` plus `effort:` in the definition. Cap
  spawning with `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH` and
  `CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS`.

## When migrating from Opus 4.x, delete

Verification steps and verify stages; forced status-message scaffolding; rules
against thinking; `budget_tokens`, sampling parameters and prefill.

## Example: review brief

```
Goal: find defects in the uncommitted change to TunnelContain.cpp before merge.
The port must match the Zero Hour legacy source, so a divergence from legacy is
a defect even when the code looks reasonable.

Derive how legacy places an exiting unit before you read the diff, then compare.

Report every finding, including uncertain and low-severity ones. For each:
severity (blocker / should-fix / nit), confidence, file:line, and a scenario
where it goes wrong. Findings and open questions only; no diff summary.
```

Sources: [prompting guide](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-opus-5),
[effort](https://platform.claude.com/docs/en/build-with-claude/effort).
