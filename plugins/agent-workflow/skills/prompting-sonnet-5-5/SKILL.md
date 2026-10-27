---
name: prompting-sonnet-5-5
description: Use when writing a prompt, subagent brief, system prompt, agent definition or standing instructions that Claude Sonnet 5.5 (claude-sonnet-5-5, or model "sonnet" in Claude Code 2.1.284+) will execute, including implementer, test-author and scout subagents, when choosing Sonnet 5.5 effort or thinking settings, or when migrating prompts or API code written for Sonnet 5.
---

# Prompting Claude Sonnet 5.5

Wording and settings only; routing and brief structure are in
`delegating-to-subagents`. Sonnet 5 prompts work unchanged, so the patterns in
`prompting-sonnet-5` still apply: state the full scope, give the whole task up
front, and ask for every review finding. For the hardest long-horizon work, use
Opus 5.5.

## Settings

- **Effort:** `low`, `medium`, `high` (API default), `xhigh`, `max`. Claude Code
  defaults to `medium`. Levels are recalibrated from Sonnet 5, so re-run your
  sweep. Starting points: `medium` for well-specified agentic coding, `high` for
  harder or longer tasks, `low` or `medium` for chat. Use `xhigh`/`max` only
  where you've measured a gain.
- **Effort changes behaviour, not just depth.** At `low` it can skip verifying a
  change. At `low` and `medium` it may stop to check in before finishing. At
  higher levels it adds more unrequested work. See the table below.
- **Less thinking:** lower effort; prompt lines asking it to think less don't
  work reliably. `max_tokens` includes thinking; use 128k and stream for
  agentic coding.
- **Thinking can't be turned off.** On the API the lowest setting is
  `thinking: {"type": "between_tools"}`, accepted at `high` or below. With it,
  per-message effort changes return a 400, and tool-less requests get no
  thinking at all, so keep adaptive thinking for reasoning tasks.
- **Caching:** changing top-level effort breaks the cache; per-message effort
  (beta) keeps it. Keep conversations append-only, because thinking blocks are
  tied to the prefix.
- **Price:** $2 / $10 per 1M tokens; cache reads $0.20.
- **Claude Code:** `model: sonnet` runs Sonnet 5.5 on the Anthropic API. Set
  `effort:` in the definition; pin `claude-sonnet-5` to keep Sonnet 5.
  Cyber-flagged requests fall back to Sonnet 5. Biology-flagged requests are
  refused with no fallback, so send biology-adjacent work to another model.

## Tendencies and what to write

| Sonnet 5.5 by default | Write this |
|---|---|
| At `low`/`medium`, stops to confirm a plan or ask whether to continue before a coding task is done. | Raise effort, or say: keep working until everything asked is done; stop only when blocked or before a risky step. Sessions run longer. |
| Adds tests, docs and small files you didn't ask for, more at higher effort. | If you want only what was asked: once the work is done and checked, stop and report, and mention suggested extras at the end instead of doing them. |
| At `xhigh`/`max`, starts its own review and hardening rounds, sometimes with reviewer subagents. | Run routine work at `high` or below. Otherwise say: when checks pass, stop; no self-started reviews or reviewer subagents unless asked. |
| Starts building on open-ended requests when you wanted ideas. | Ask for ideas or a plan explicitly, and say not to build until told. |
| At `low`, can report code done without a check that exercises it. | Require a real check (tests, type-checker, build or the changed command) before reporting done. Syntax-only checks don't count. Missing declared dependencies are installed with the project's own package manager, never sudo. If no check can run, say which and why. |
| Answers from training knowledge where a search would catch changed details. | Remove "minimize tool calls" wording. Tell it to search specifics that change (rules, requirements, prices) even when confident. |
| Skips thinking on multi-step tasks that must return JSON, and gets them wrong. | Use structured outputs and add "Think the problem through before you answer", or use `xhigh`. Treat a `max_tokens` stop as a failure. Without structured outputs, parse the last JSON value in the response. |
| Treats user text arriving right after tool results as a possible injection. | Never put user text inside a `tool_result`. Send it as a text block after the last `tool_result`, keep harness notices in a separate system message, and drop per-step token countdowns. |
| Occasionally miscases a tool or parameter name. | Accept unambiguous case mismatches, or return `is_error` naming the exact expected name. |
| Progress notes arrive as `thinking` blocks, empty by default. | Set `display: "updates"`. Remove "hold all findings for the end" instructions. |
| Misses detail in dense charts and technical drawings. | Give it crop, zoom or code tools; for charts this beats raising effort. |
| Declines `cyber`, `bio`, `frontier_llm`, `reasoning_extraction` and `general_harms` requests. | Don't ask for reasoning in the response; read summarized thinking instead. |

## Example: implementer brief at `medium`

```
Goal: rename the field userId to accountId across packages/api so the API uses
one name. The DB column stays user_id, so every mapper must translate between
user_id and accountId in both directions.

Rename every occurrence in the owned files, not a sample: types, schema keys,
object keys, destructuring, route params and their req.params reads, OpenAPI
properties, fixtures, mocks and snapshots. Also rename compound names
(findByUserId -> findByAccountId).

owns: <file list>. If a change needs a file outside owns, stop that item and
report "blocked: needs <file>".

Keep going until every occurrence is renamed and the checks below pass. Don't
add tests, files or refactors beyond the rename; mention any you'd suggest at
the end.

Done when: typecheck and tests pass (run them; don't report done without
their output); `rg -w userId packages/api` returns only your exception list.

Return: files changed, exceptions with file:line and reason, and the output
of each check.
```

It lists every occurrence type because Sonnet won't infer them. It says to
keep going, because at `medium` it may stop early. It rules out extras and
requires check output.

Sources: [prompting guide](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-sonnet-5-5),
[what's new](https://platform.claude.com/docs/en/models/sonnet-5-5/whats-new-sonnet-5-5),
[Claude Code models](https://code.claude.com/docs/en/model-config).
