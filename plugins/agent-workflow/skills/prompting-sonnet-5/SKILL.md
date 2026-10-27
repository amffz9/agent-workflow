---
name: "prompting-sonnet-5"
description: Use when writing a prompt, subagent brief, system prompt, agent definition or standing instructions that Claude Sonnet 5 pinned as claude-sonnet-5 will execute, when choosing Sonnet 5 effort or thinking settings, or when migrating prompts written for Sonnet 4.x. In Claude Code 2.1.284+ the "sonnet" alias runs Sonnet 5.5 instead; use prompting-sonnet-5-5 for that.
---

# Prompting Claude Sonnet 5

For pinned `claude-sonnet-5` only; `model: sonnet` now runs Sonnet 5.5
(`prompting-sonnet-5-5`). Sonnet 5 does exactly what the brief says and no more, so most of the work is
stating the whole scope and the whole task up front.

## Tendencies and what to write

| Sonnet 5 by default | Write this |
|---|---|
| Won't extend an instruction to similar items or infer work you didn't ask for. | Name the full scope: "every handler in these files, not just the first", "update the tests as well as the code". |
| Loses efficiency when the task arrives across several turns. | Put the whole task, intent and constraints in the first message. |
| Reasons shallowly on multi-step problems at `low`/`medium`. | Raise effort. If it must stay low, say the task needs multi-step reasoning. |
| Takes "only high-severity" or "don't nitpick" literally and withholds findings. | Ask for every finding with confidence and severity, or define the bar concretely. |
| Uses tools less when thinking is off, or when it doesn't know why a tool matters. | Keep thinking on. Say when to use each tool and what for. Be directive: "change this function". |
| Gives useful progress updates unprompted. | Delete scaffolding that forces status messages. |
| Falls into one house style on open-ended frontend work. | Give a concrete spec, or have it propose distinct directions and pick one first. |

Add only if the problem shows up: no speculative abstractions; no hard-coding to
pass tests; read code before making claims about it; ask before destructive or
externally visible actions.

## Settings

- **Effort:** `low`, `medium`, `high` (default), `xhigh`, `max`. `high` for most
  work, `xhigh` for the hardest agentic coding, `medium` when cost matters, `low`
  for short, well-scoped subagent work.
- **Effort can't change mid-conversation**; changing it loses the prompt cache.
- **Thinking** is adaptive and on by default; `budget_tokens` returns a 400.
- **API:** the tokenizer yields about 30% more tokens than Sonnet 4.6, so recount
  budgets. Sampling parameters and prefill return 400s.
- **Claude Code:** `model: claude-sonnet-5` and `effort:` in the definition. If a
  definition pins `effort: medium` and the task needs multi-step reasoning,
  raise the effort rather than padding the brief.

## Example: implementer brief

```
Goal: rename the field userId to accountId across packages/api so the API uses
one name. The DB column stays user_id, so every mapper must translate between
user_id and accountId in both directions.

Rename every occurrence in the owned files, not a sample: types, schema keys,
object keys, destructuring, route params and their req.params reads, OpenAPI
properties, required lists and examples, fixtures, mocks and snapshots. Also
rename compound names (findByUserId -> findByAccountId).

owns: <file list>. Leave rateLimit.ts and its test alone; I'm editing them. If
a change needs a file outside owns, stop that item and report
"blocked: needs <file>".

Done when: typecheck passes; tests pass apart from the listed baseline failures;
`rg -w userId packages/api` returns only your exception list; the user_id count
is unchanged.

Return: files changed, each exception with file:line and reason, and the output
of the four checks.
```

It lists every kind of occurrence because Sonnet 5 won't infer them.

Sources: [prompting guide](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-sonnet-5),
[effort](https://platform.claude.com/docs/en/build-with-claude/effort).
