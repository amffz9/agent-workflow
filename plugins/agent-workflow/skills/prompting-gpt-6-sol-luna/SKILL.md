---
name: "prompting-gpt-6-sol-luna"
description: Use when writing a prompt, codex exec brief, AGENTS.md or agent definition that GPT-6.1 Sol, GPT-6 Sol or GPT-6 Luna (gpt-6.1-sol, gpt-6-sol, gpt-6-luna) will execute, when choosing their reasoning effort, when choosing between Sol, Luna and Astra, or when migrating from gpt-6-sol or GPT-5.6.
---

# Prompting GPT-6.1 Sol, GPT-6 Sol and GPT-6 Luna

Wording only; running codex is in the `codex` skill. OpenAI has one prompting
guide for the whole GPT-6 family, 6.1 Sol included, written from Astra's
behaviour. Start from it (`prompting-gpt-6-astra`), check whether Sol and Luna
actually pause the way Astra does, and keep a few hard lines around
irreversible actions. Use `gpt-6.1-sol` for new work; `gpt-6-sol` is the
previous Sol.

## Which model

| Model | For | Price per 1M (in / out) | Codex starting effort |
|---|---|---|---|
| `gpt-6-luna` | Clear, repeatable tasks: extraction, classification, transforms, focused coding | $0.10 / $0.50 | `high` |
| `gpt-6.1-sol` | Complex coding, computer use, reviews, long-running work; near-Astra on many tasks | $2 / $10 (cached input $0.10) | `medium` |
| `gpt-6-sol` | Previous Sol; keep only for `none` effort or Chat Completions tool calls | $2 / $10 | `medium` |
| `gpt-6-astra` | The hardest end-to-end work and research | $10 / $50 | `low` |

Try 6.1 Sol before Astra and compare on your own tasks; Astra still leads on the
hardest research work. There is no GPT-6 Terra or GPT-6.1 Astra. Prompts over 272K input tokens cost more for the whole
request, so point to files instead of pasting large context.

## What to write

| GPT-6 family tendency | Write this |
|---|---|
| Asks for clarification and approval where older models proceeded. | Say which decisions it may make on its own assumptions (recording each) and which need confirmation. Do the reversible work first so approval is the last step. |
| Follows AGENTS.md and skills closely; conflicts make it pause. | "Where this brief and AGENTS.md conflict, this brief wins for this task." Name AGENTS.md rules; don't paraphrase them. |
| Tends toward lists, tables and stock phrases. | Name the format or exact report fields. One format line is usually enough; Sol and Luna already write short and plain. |
| Over-tests small changes. | No new tests for reversible, low-impact edits; rerun only after new changes or failures. |
| Delegates less than would save time. | Say which parts to split and what each returns. |

Keep these, because each guards an irreversible action at the cost of one line:

- Name targets exactly. If a named target doesn't exist, stop and report rather
  than substitute another.
- List what's off-limits: credential stores, `.env` files, other users' data,
  anything outside `-C`.
- Require evidence for verification claims: the command and its output, or
  "not verified".

Replace old anti-persistence wording ("don't keep going") with a full definition
of done, the loops it may run without asking, and a stop point.

OpenAI reports 6.1 Sol is better than 6 Sol at keeping to explicit
restrictions, flagging broken tools and avoiding unapproved outcomes. Keep the
three lines anyway; they cost little.

For Luna, give one well-specified task and a closed `owns:` list. Send ambiguous
or judgment-heavy multi-file work to Sol.

## Settings

- **Effort:** `low`, `medium` (default), `high`, `xhigh`, `max`. 6.1 Sol and
  Astra have no `none` or `minimal`: replace them with `low`, which is slower
  and costs more because it reasons. 6 Sol and Luna also accept `none`. Levels
  don't map across generations; start a notch lower than you used before. Luna
  tops out at `max` (no Ultra in Codex).
- **Changing effort mid-conversation:** add a `configuration_update` item rather
  than changing `reasoning.effort`, which breaks the cache.
- **API:** use the Responses API for tool calls. On 6.1 Sol, Chat Completions
  takes no tools at all; on 6 Sol and Luna it takes function calls only at
  `none`. Above `none`, remove `temperature`, `top_p` and `top_logprobs` (and
  `logprobs` in Chat Completions).
- **Moving from `gpt-6-sol`:** change the slug, map `none` to `low`, and move any
  Chat Completions tool calls to Responses.
- **Codex:** `-m gpt-6.1-sol|gpt-6-luna -c model_reasoning_effort="<level>"`.
  6.1 Sol has Standard and Fast speeds; Ultrafast is coming later. Max and
  Ultra depend on your settings.

## Example: 6.1 Sol review (`codex exec -s read-only`)

```
Where this brief and AGENTS.md conflict, this brief wins for this task.

Goal: find defects in the uncommitted change to src/billing/periods.py. The
refactor was labelled "no behaviour change", so any difference in which events
land in which billing period is a defect.

Derive how aggregate.monthly_usage bounded a period before the change, then
compare Period.contains against it, including both boundaries and timezones.
If something is ambiguous, pick the most plausible reading, note it as an
assumption, and keep going. Reason from source; don't run tests.

Output: every finding, most severe first, with severity, confidence, file:line
and an input that goes wrong. Then assumptions, then open questions. Mark
anything unconfirmed "not verified".
```

## Example: Luna implementation (`codex exec -s workspace-write`)

```
Where this brief and AGENTS.md conflict, this brief wins for this task.

Goal: rename userId to accountId in packages/api/src/routes/accounts.ts and
accounts.test.ts: types, object keys, destructuring, req.params reads and
fixtures.

Edit only those two files. Don't run git or read .env or credential files. If
a change needs another file, list it with the reason instead of editing it.

Done when: `pnpm --filter api exec vitest run src/routes/accounts.test.ts`
passes. Run it, fix failures in the two files and rerun, up to three times.

Report: files changed, the final test output verbatim, and anything not
verified.
```

Sources: [GPT-6 guide](https://developers.openai.com/api/docs/guides/latest-model?model=gpt-6.1-sol),
[6.1 Sol model page](https://developers.openai.com/api/docs/models/gpt-6.1-sol),
[Codex models](https://learn.chatgpt.com/docs/models).
