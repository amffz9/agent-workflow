---
name: "prompting-gpt-6-astra"
description: Use when writing a prompt, codex exec brief, AGENTS.md, Codex skill or agent definition that GPT-6 Astra (gpt-6-astra) will execute, when choosing Astra reasoning effort, or when Astra stops early, asks too many clarifying questions, over-tests or pauses on conflicting instructions.
---

# Prompting GPT-6 Astra

Wording only; running codex is in the `codex` skill. For `gpt-6.1-sol`,
`gpt-6-sol` and `gpt-6-luna` use `prompting-gpt-6-sol-luna`.

Astra under-acts: it asks, pauses and stops early, and prompts written for
older models make that worse. Push it to act and delete old scaffolding.

## Tendencies and what to write

| Astra by default | Write this |
|---|---|
| Asks clarifying questions and seeks approval instead of proceeding on reasonable assumptions. | Say which decisions it may make on its own assumptions (recording each) and which need confirmation. Bias toward action and carry the task to completion. |
| Stops once a narrow reading of the task is satisfied. | Define done in full: make the change, run it, inspect the result, fix failures. Say where to stop. |
| Reads strict safety wording as a hard stop. | Grant safe loops ("run local tests, fix failures from this change, rerun without asking"). Keep prohibitions for destructive or external actions only. |
| Pauses when the prompt, AGENTS.md and skills conflict. | "Where this brief and AGENTS.md or a skill conflict, this brief wins." Don't restate AGENTS.md rules in new words. |
| Follows blanket rules literally ("always test"), burning turns. | Make rules conditional pointers: "database.md for schema changes". |
| Tests more than small changes need. | No tests for reversible, low-impact edits; rerun only after new changes or failures. |
| Delegates less than would save time. | Say which parts go to parallel subagents and what each returns. |
| Defaults to lists, tables and stock phrases. | Name the format or exact report fields. |

## Settings

- **Effort:** no `none`; migrate `none` or `minimal` to `low`. Codex's model
  cache is the authority on what `codex exec` accepts. Tune effort after the
  prompt, not instead of it.
- **Changing effort mid-conversation:** use a `configuration_update` item to keep
  the cache.
- **Cost:** $10 / $50 per 1M tokens, five times GPT-6.1 Sol, which comes close
  on many tasks. Try 6.1 Sol first.
- **Codex:** `-m gpt-6-astra -c model_reasoning_effort="<level>"`.

## Delete from older prompts

Step-by-step process recipes; reminders to test and verify; broad skill
descriptions (narrow them to one workflow); strict wording that doesn't mark a
real safety line.

## Example: hard review (`codex exec -s read-only`)

```
Where this brief and AGENTS.md conflict, this brief wins for this task.

Goal: find every defect in the uncommitted change to TunnelContain.cpp. The
port must match Zero Hour's legacy source, so a divergence from legacy is a
defect even when the code looks reasonable.

Proceed without asking questions. If something is ambiguous, pick the most
plausible reading, note it as an assumption, and keep going. Reason from
source; the sandbox is read-only, so don't run tests or builds.

Done when: you've worked out legacy's exit placement (every exit path, the
fallback, any random draws), compared the diff against it, and judged whether
the new tests would have failed before the change.

Output: findings first, most severe first, with severity, confidence, file:line
and a failure scenario. Then assumptions, then open questions.
```

Sources: [GPT-6 guide](https://developers.openai.com/api/docs/guides/latest-model?model=gpt-6-astra),
[skills and prompts for Astra](https://developers.openai.com/blog/rethinking-skills-and-prompts-for-gpt-6-astra).
