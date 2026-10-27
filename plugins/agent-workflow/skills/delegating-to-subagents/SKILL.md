---
name: "delegating-to-subagents"
description: "Use when about to call the Agent tool, run codex exec, fan work out to parallel or background agents, choose a subagent type, model or worktree isolation, or write a prompt or brief for another agent, including reviews and second opinions, and when a user says to use many agents."
---

# Delegating to subagents

A delegated agent knows only its prompt, its definition and CLAUDE.md/AGENTS.md.
Agents cost 4–15x the tokens of doing the work yourself, so delegate only when a
row below fits. Codex CLI mechanics are in the `codex` skill; sources are in
`vendor-guidance.md`.

## Route

| The work is… | Send it to |
|---|---|
| One known file, one grep, or one build/test run whose output decides your next step | Yourself |
| A search across many files where you need only the conclusion | A read-only scout (haiku/sonnet). Re-read only the citations your decision rests on. |
| A well-specified edit with a closed set of files | An implementer (sonnet) with an `owns:` list |
| One type-connected change, or edits whose files overlap | One agent |
| Edits with disjoint files | Parallel agents, each with `owns:`, launched in one message and backgrounded |
| Work that needs most of this conversation | A fork, or yourself |
| An independent review or second opinion | A different model: `codex`, read-only. An opus reviewer if codex is unavailable. |
| A decision that belongs to the user | The user |

- **Prefer a matching custom agent in `.claude/agents/`.** Its definition fixes
  model, effort, tools and report format. The Agent tool has no effort
  parameter, so only a definition sets effort.
- **`opus` and `sonnet` are aliases that resolve by Claude Code version** (and
  by provider, if you're not on the Anthropic API). Pin the full ID
  (`claude-opus-5-5`) in a definition when the model matters, and load the
  prompting skill for what the alias actually resolves to.
- **Set `effort:` in every definition.** The default differs by model and has
  moved between Claude Code releases, so an unset lane changes behaviour when
  you update. Choose the level per lane and re-check it after a model change;
  effort scales are recalibrated per release.
- **Implementer briefs say to keep going until done-when is met,** regardless
  of level. Sonnet 5.5 at lower effort may stop to check in early, and the
  line costs nothing where it isn't needed.
- **Choose model and effort by cost per task, not price per token.** Effort
  multiplies tokens, so a cheaper model near the top of its range can cost
  more than a stronger model lower in its range for the same result. Before
  raising an implementer's effort, compare against the next model up at a
  lower level. On Cursor's CursorBench in October 2026, Opus 5.5 at `high`
  outscored Sonnet 5.5 at `max` for a little over half the cost per task.
  Re-check when either model changes.
- **Treat "this lane needs `xhigh` or `max`" as a routing signal.** It usually
  means the task is open-ended, which belongs to the stronger model, or
  under-specified, which belongs in the brief. Sonnet 5.5 at those levels also
  starts its own review rounds and reviewer subagents, so a delegated Sonnet
  run at `xhigh`/`max` is fan-out you didn't choose. If you run one anyway,
  the brief says: when checks pass, stop; no self-started reviews or reviewer
  subagents.
- **"Use as many agents as you want" is permission, not a target.** Opus models
  over-delegate.
- **Run in parallel only when** no agent needs another's output, no two write
  the same file, and nobody runs state-changing git on a checkout another live
  agent is reading.

## Worktree isolation

`isolation: "worktree"` branches from `origin/HEAD` (from local HEAD with
`worktree.baseRef: "head"`) and checks out tracked files only. Uncommitted work
and gitignored files (`.env`, `node_modules`) don't carry over;
`.worktreeinclude` copies gitignored files.

- If the task depends on your branch or uncommitted work, don't isolate. Use the
  shared checkout with disjoint `owns:`, or brief the agent to
  `git checkout <sha>` if the work is committed.
- If you isolate, put the setup step in the brief and ask for the worktree path.
  You apply its diff.

## Write the brief

1. **Goal.** One sentence of outcome plus why it matters, so the agent can handle
   cases you didn't foresee.
2. **Evidence.** Paths, `path:line`, error text, decisions made, what's ruled
   out. Label hypotheses as hypotheses.
3. **Scope.** The `owns:` files, what's off-limits, and what to do when it needs
   something outside (`blocked: needs X`).
4. **Done when.** Observable criteria, and which checks the agent runs versus
   you.
5. **Return.** The fields you'll act on. Large output goes to a file; return the
   path.

For a custom agent, the definition already supplies the contract and report
format: write parts 1–4, and add fields as "In addition to your normal report: …".

Load the prompting skill for the model that will run the brief:

| Model | Skill |
|---|---|
| `opus`, `claude-opus-5-5` | `prompting-opus-5-5` |
| `claude-opus-5` (pinned) | `prompting-opus-5` |
| `sonnet`, `claude-sonnet-5-5` | `prompting-sonnet-5-5` |
| `claude-sonnet-5` (pinned) | `prompting-sonnet-5` |
| `gpt-6.1-sol`, `gpt-6-sol`, `gpt-6-luna` | `prompting-gpt-6-sol-luna` |
| `gpt-6-astra` | `prompting-gpt-6-astra` |
| `gpt-5.6-*` | `prompting-gpt-5-6` |

For any model, give each directive its reason, in plain case, with no CRITICAL
or ALL-CAPS.

## Reviewer briefs

- **Ask for every finding,** each with severity (blocker / should-fix / nit),
  confidence, `file:line` and a concrete failure scenario, and filter afterwards.
  "Only high-severity" makes reviewers withhold findings.
- **Keep the reviewer independent.** Have it derive behaviour from source before
  reading the author's claim, and give that claim as a hypothesis to falsify, or
  withhold it.

## Briefing codex

- **Precedence:** include "Where this brief and AGENTS.md conflict, this brief
  wins for this task." Name AGENTS.md rules rather than paraphrasing them;
  contradictions burn reasoning.
- **Read-only sandbox:** tests, typecheckers and caches write files, so say
  "reason from source; do not run tests or builds" and run them yourself.
- **Implementation:** give the full definition of done, a stop point, and the
  loops it may run without asking. GPT-6 models need permission to act; GPT-5.6
  needs hard boundaries.
- **No upfront plan:** `-o` keeps only the final message.
- **Output order:** findings by severity with `file:line`, then open questions,
  summary last.

## When results return

1. Check the claims that matter against the code they cite.
2. Check changes stayed inside `owns:` with `git status` or the diff.
3. Follow up with SendMessage to the same agent, which keeps its context.
4. An Opus 5.5 agent can return a status report with work still open. If
   done-when isn't met and no blocker is named, send the open items back. Stop
   after two or three nudges and look at the run yourself.