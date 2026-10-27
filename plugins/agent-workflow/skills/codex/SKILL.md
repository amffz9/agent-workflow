---
name: "codex"
description: 'Delegate a review, analysis, or (with approval) an implementation to the codex CLI. Use when a plan, design doc, diff, or implementation needs a second opinion from an independent model, or when a well-specified implementation should be executed by a stricter instruction-follower. Triggers: "run it by codex", "get codex to review", "second opinion on this plan", "adversarial review", "have codex check", "have codex implement".'
---

# Delegating to codex

`codex exec` runs the codex CLI non-interactively. Delegate judgment or
execution, not facts: anything directly checkable is cheaper to check yourself.

**On Windows, run it through the Bash tool, not PowerShell.** The command below
needs a heredoc and `< /dev/null`. Run it from the project root and pass
`-C .`, so no machine path appears in the command.

| Mode | Sandbox | Model | Needs approval? |
|---|---|---|---|
| Review / analysis | `-s read-only` | `gpt-6.1-sol` (hard ones: `gpt-6-astra`) | No |
| Implementation | `-s workspace-write` | `gpt-6-luna` | Yes, ask first |

## Models and cost

| Slug | Price per 1M (in / out) | Start at | Roughly | Use for |
|---|---|---|---|---|
| `gpt-6-luna` | $0.10 / $0.50 | `high` | Sonnet / Haiku | Implementation from a precise brief |
| `gpt-6.1-sol` | $2 / $10 | `medium` | Opus | Reviews and everyday work; near-Astra on many tasks |
| `gpt-6-astra` | $10 / $50 | `low`–`medium` | Fable | Hard reviews and subtle bugs only |
| `gpt-6-sol` | $2 / $10 | `medium` | | Previous Sol; fallback if 6.1 isn't enabled for you |
| `gpt-5.6-*` | Sol $4 / $20 | | | Fallback during the rollout |

Prices and starting efforts are from OpenAI's docs. "Roughly" carries over your
GPT-5.6 calibration to the equivalent 6-series tier. Neither has been checked on
your machine: run one small read-only job and check
`~/.codex/models_cache.json` first, since the cache is the authority on slugs
and efforts. On Windows, read the
cache as UTF-8.

6.1 Sol has no `none` effort; its lowest is `low`. On Enterprise and Edu an
admin must enable it first.

- **Reviews → 6.1 sol.** Escalate to astra, at five times the price, only when a sol
  review comes back thin on something known to be hard, or the failure mode is
  expensive. Not for small diffs.
- **Implementation → luna.** Give it a closed file list and one well-specified
  task; send multi-file or judgment-heavy work to sol.
- **Effort:** use the lowest that gets the result. `xhigh`/`max` for the hardest
  problems; `ultra` fans out to subagents (not on luna) when the work splits
  cleanly. Levels don't carry across generations. Always pass `-m` and
  `-c model_reasoning_effort=` so a moved default doesn't change the run.

```sh
-m gpt-6.1-sol -c model_reasoning_effort="medium"  # reviews
-m gpt-6-astra -c model_reasoning_effort="medium"  # hard reviews only
-m gpt-6-luna  -c model_reasoning_effort="high"    # implementation
```

## The command

```sh
codex exec -s read-only -C . \
  -m gpt-6.1-sol -c model_reasoning_effort="medium" \
  -o <scratchpad>/codex-review.md \
  "$(cat <<'PROMPT'
<the brief>
PROMPT
)" < /dev/null > <scratchpad>/run.log 2>&1
```

| Flag | Why |
|---|---|
| `-s read-only` | Reads the repo, never writes. Required for review work. |
| `-C .` | The project root, so relative paths in the brief resolve. |
| `-o <file>` | Writes only the final message; read that, not the event stream. |
| `< /dev/null` | Stops piped stdin being appended to the prompt. |

- **Always `run_in_background: true`.** Foreground Bash caps at 600s; a
  background call has no timeout and notifies you on completion.
- **Stop a run with `TaskStop`.** On Linux never `pkill -f "codex exec"`: it
  matches your own wrapper shell and kills the run you launched. With
  `taskkill`, target `/PID`, never a name pattern.
- "Reading additional input from stdin..." always prints; it isn't a hang.

## Writing the brief

1. **The artifact:** path, and that codex should read it plus the code it
   describes.
2. **The question:** "is this implementation-ready", not "what do you think".
3. **The bar:** what counts as a finding, what's out of scope, what done is.
4. **Severity labels,** so findings arrive ranked.
5. **file:line for every claim,** which makes fabricated findings visible.
6. **Read-only:** no files changed, no tests run.

Load `prompting-gpt-6-sol-luna` for 6.1 sol, 6 sol or luna, `prompting-gpt-6-astra` for
astra, and `prompting-gpt-5-6` for any `gpt-5.6-*` slug.

## After it returns

Findings are input, not verdict. Read the cited code before acting; a reviewer
without project history flags things already settled. Tell the user what
survived verification and what didn't, with reasons.

## Implementation mode

A second agent editing the working tree: **ask before the first one in a
session** and say what codex may write. Use the command above with
`-s workspace-write -m gpt-6-luna -c model_reasoning_effort="high"` and
`-o <scratchpad>/codex-impl.md`.

Good fit: a written plan, acceptance criteria, a mechanical migration across
many sites. Poor fit: exploratory work, a moving design, or judgment calls the
spec doesn't contain.

- **Name the project invariants the tests will trip on.** The usual failure is a
  test asserting something a project rule deliberately forbids, which looks
  like an implementation bug. Put each such rule in the brief with an example,
  and say not to "fix" it by editing src/.
- **Verification stays with you.** Tell codex not to run tests, typechecks or
  git; run them yourself and read the diff. A self-reported "all tests pass" is
  not evidence.

## Other subcommands

- `codex exec review`: diff-oriented review of the current repository.
- `codex exec resume --last`: continue the previous session without re-briefing.
- `codex exec --output-schema <file>`: JSON-shaped response for machine reading.

## Safety

- Never `--dangerously-bypass-approvals-and-sandbox` or `-s danger-full-access`;
  `workspace-write` only for an approved implementation.
- Whatever the brief points codex at leaves the machine. Don't point it at
  secrets.
