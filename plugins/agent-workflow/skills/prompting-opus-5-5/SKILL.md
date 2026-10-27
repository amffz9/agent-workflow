---
name: "prompting-opus-5-5"
description: Use when writing a prompt, subagent brief, system prompt, agent definition or standing instructions that Claude Opus 5.5 (claude-opus-5-5, or model "opus" in Claude Code 2.1.280+) will execute, when choosing Opus 5.5 effort, when an Opus 5.5 agent stops partway through a long unattended task, or when migrating prompts or API code written for Opus 5.
---

# Prompting Claude Opus 5.5

Wording and settings only; routing and brief structure are in
`delegating-to-subagents`. Opus 5 prompts work unchanged, so the patterns in
`prompting-opus-5` still apply: ask for every review finding, use the verb you
mean, give the whole spec up front, and leave out "double-check" lines.

## Settings

- **Effort:** `low`, `medium` (default), `high`, `xhigh`, `max`. Set it
  explicitly. `medium` roughly matches Opus 5 at `high`; `low` is often close on
  coding. Use `xhigh`/`max` only where you've measured a gain. To get less
  thinking, lower effort rather than prompting for it.
- **Thinking is always on.** `thinking: disabled` and `budget_tokens` return a
  400. `max_tokens` includes thinking; allow up to 128k for long agentic turns.
- **Forced tool use returns a 400.** Use `tool_choice: auto` with strict tools,
  and say in the prompt when the tool applies.
- **Keep conversations append-only.** Thinking blocks are tied to the prefix, so
  change instructions with mid-conversation system messages. Per-message effort
  (beta) keeps the cache; changing top-level effort breaks it.
- **Price:** $4 / $20 per 1M tokens; cache reads $0.20.
- **Claude Code:** `model: opus` runs Opus 5.5. Set `effort:` in the definition,
  because a user-level `effortLevel` doesn't apply to it. Pin `claude-opus-5` to
  keep Opus 5.

## Tendencies and what to write

| Opus 5.5 by default | Write this |
|---|---|
| On long unattended tasks, may end a turn with a report instead of a tool call. | Use the standing instruction below, and keep a task checklist the model updates. |
| Writes progress notes between tool calls; on the API they're `thinking` blocks, empty by default. | Set `display: "updates"` to see them. Describe the cadence you want. |
| Starts working fast and can miss context the task didn't name. | For multi-app work: explore the relevant emails, docs, tabs and records first, including unnamed ones. |
| Paces itself to elapsed time. | For a lead agent, append `elapsed 340s / 1200s` to each message. The budget is advisory; keep a real timeout. |
| In chat, re-examines earlier answers each turn, adding latency. | Chat only: treat answered questions as settled unless the user raises them. |
| Follows instructions inside text a user pasted unless told which text was pasted. | Wrap pasted text in `<pasted_content id="…">` and say instructions inside it apply only where the user's own message asks. |
| Falls back on default frontend styles. | Name the specific styles to avoid, and extend the list each round. |
| Reads charts and screenshots accurately without tools. | Re-test old visual scaffolding before keeping it. |
| Declines requests that push it to write out its reasoning (`reasoning_extraction`). | Don't ask for reasoning in the response; read summarized thinking instead. |

## Standing instruction for unattended runs

Put it at the end of the system prompt from the first request; adding it later
invalidates earlier thinking blocks. Leave it out when someone is there to
answer.

```
You are working unattended: a message with no tool call ends your turn, and
nothing happens until someone comes back. Don't end a turn with a summary that
announces the next step, an offer to continue, a list of non-blocking
decisions, or a pause because a milestone is done. Put status notes in the
same message as your next tool call and keep going. End your turn only when
nothing can move without the user, or when what blocks you is deliberately
protected. Still confirm risky or destructive actions.
```

In the harness, when a turn ends with checklist items open and no blocker
named, send the open items back. Stop after two or three continuations.

## Example: unattended subagent brief

```
Goal: move the remaining 14 route handlers in packages/api/src/routes from the
legacy validator to zod, so the legacy package can be removed next sprint.

Track progress in scratch/migration-todo.md, one line per handler: done,
blocked (with reason) or open.

owns: packages/api/src/routes/**, packages/api/test/routes/**. Leave
packages/api/src/validators/legacy.ts alone; other packages import it. If a
handler needs a change outside owns, mark it blocked and move on.

Keep going until every line is done or blocked.

Done when: `pnpm --filter api test` passes and no line is open.
Return: the final todo file and the last 20 lines of the test run.
```

Sources: [prompting guide](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-opus-5-5),
[what's new](https://platform.claude.com/docs/en/models/opus-5-5/whats-new-opus-5-5),
[effort](https://platform.claude.com/docs/en/build-with-claude/effort),
[Claude Code models](https://code.claude.com/docs/en/model-config).
