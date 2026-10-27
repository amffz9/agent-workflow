---
name: "prompting-gpt-5-6"
description: Use when writing a prompt, codex exec brief, AGENTS.md or agent definition that GPT-5.6 Sol, Terra or Luna (gpt-5.6-sol, gpt-5.6-terra, gpt-5.6-luna) will execute, when choosing their reasoning effort, or when a GPT-5.6 run overreaches, substitutes targets, or claims unverified results. For gpt-6.1-sol, gpt-6-sol or gpt-6-luna use prompting-gpt-6-sol-luna instead.
---

# Prompting GPT-5.6 (Sol, Terra, Luna)

For briefs that pin a `gpt-5.6-*` slug. GPT-6.1 Sol and GPT-6 Luna are better
and half the price; use `prompting-gpt-6-sol-luna` for those.

GPT-5.6 is literal and thorough, and Sol can pursue a goal past what you
intended. Write a short prompt with hard boundaries.

## Which tier

| Tier | For | Price per 1M (in / out) |
|---|---|---|
| Luna | Clear, repeatable, high-volume execution | $0.20 / $1.20 |
| Terra | Exploration, large-file review, parallel workers returning summaries | $2 / $12 |
| Sol | Ambiguous multi-step work, reviews, planning (most prone to overreach) | $4 / $20 |

## What to write

| GPT-5.6 by default | Write this |
|---|---|
| Sol takes actions beyond what was intended, worst at high effort and under "keep going" prompts. | Give scope, done criteria and a stop point. No "never stop". Use `high`, not `max`. |
| Substitutes targets it can't find, and may delete them. | Name targets exactly: "If a named target doesn't exist, stop and report. Don't substitute." |
| Claims results were verified when they weren't. | Require the command and its output for every verification claim, or "not verified". |
| Reaches for credentials it wasn't given. | List what's off-limits: credential stores, `.env`, other users' data, anything outside `-C`. |
| Luna overwrites more on complex tasks. | Give Luna a closed `owns:` list and one task; send multi-file work to Terra or Sol. |
| Takes ALWAYS/NEVER as absolute. | Keep absolutes for real invariants; word judgment calls as judgment calls. |
| Adopts a stated diagnosis readily. | Have reviewers derive behaviour from source before seeing the author's claim. |

Describe the outcome and stopping rule, not every step; lean prompts score
better on this model.

## Settings

- **Effort:** `none` to `max`, API default `medium`. Codex's cache can differ, so
  pass `-c model_reasoning_effort=` explicitly. `low` for speed, `medium`
  balanced, `high` for hard debugging and review; `xhigh`/`max` only with
  measured gains.
- **Verbosity** is separate: `model_verbosity` in Codex config.
- **Codex:** `-m gpt-5.6-sol|gpt-5.6-terra|gpt-5.6-luna -c model_reasoning_effort="<level>"`.

## Example: Luna implementation (`codex exec -s workspace-write`)

```
Where this brief and AGENTS.md conflict, this brief wins for this task.

Goal: rename userId to accountId in packages/api/src/routes/accounts.ts and
accounts.test.ts: types, object keys, destructuring, req.params reads and
fixtures.

Edit only those two files. Don't touch other files, run git, or read .env or
credential files. If a change needs another file, stop and report which and why.

Done when: `pnpm --filter api exec vitest run src/routes/accounts.test.ts`
passes. You may run it, fix failures in the two files and rerun up to three
times. Then stop.

Report: diff summary per file, the final test output verbatim, and anything
not verified.
```

Sources: [prompt guidance](https://developers.openai.com/api/docs/guides/prompt-guidance?model=gpt-5.6),
[system card](https://deploymentsafety.openai.com/gpt-5-6).
