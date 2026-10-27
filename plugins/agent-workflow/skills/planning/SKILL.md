---
name: planning
description: Decide how much planning a change needs, then plan it as an implementation-free contract (flow, parts, interfaces, examples) that implementation can follow mechanically. Use before any non-trivial change, and whenever the user asks for a plan, spec, design, contract, architecture or "how should we build this", when a change spans several files, touches unfamiliar code, or is hard to undo (schema, data deletion, deploys, public interfaces), and when a plan or spec review loop is running or seems to be going in circles. Skip only for one-sentence changes to familiar code that are cheap to undo.
---

# Planning

Planning exists to make implementation short and boring.
Spend only as much as the risk justifies, and stop when the tier's work is done.


## Terms

- Tier: how much planning a change gets: 0, 1 or 2.
- Contract: the Tier 2 plan. It says what each part does and how parts talk, never how they are coded.
- Part: one component of the design, named with one noun.
- Boundary part: a part that wraps something we don't control (a library, the OS, a device, another service).
- Packet: one implementer's slice of the work, with a closed list of files it may change.
- Finding: a reviewer's claim that something is wrong.


## 1. Pick a tier

Answer four questions:

- Can the diff be described in one sentence?
- How many files and interfaces does it touch?
- Is the code familiar?
- Can it be undone cheaply? Git revert counts. A deploy, a migration, deleted data or anything on a shared host does not.

Then pick:

- Tier 0: one-sentence diff, familiar code, cheap to undo.
  - Produce nothing. Implement, then run the check.
- Tier 1: several files following a known pattern and git-revertable, or one simple irreversible step (a migration, delete or deploy).
  - Produce a checklist of steps, each with the check that proves it, in the task list or your message.
  - For an irreversible step, add its safeguard: backup, dry run, check before and after, and the user's go-ahead.
- Tier 2: unfamiliar or ambiguous, several interfaces, or irreversible and multi-step.
  - Produce a contract (section 3) and get one independent review (section 4).

Risk beats brevity: a one-sentence change that is irreversible or unfamiliar is not Tier 0.

If Tier 0 or 1 work grows a new interface or reaches unfamiliar code, stop and re-tier. Keep what you learned as the start of the new plan.

When undo is free, a cheap attempt or a throwaway spike can replace the contract. A failed attempt often teaches more than a longer plan. If it fails, or the shape is still unclear, move to Tier 2 and keep only what the spike proved. Checkpoints don't undo side effects outside the repository.

Never estimate time. Size work by files, interfaces and risk. An estimate with no data behind it is noise.


## 2. Decisions and unknowns

- Ask the user only for choices that are theirs: policy, priorities, trade-offs the code can't settle. Batch them into one question.
- Mark each of those `[NEEDS CLARIFICATION: question]`. They block the plan.
- Mark every other unknown `[ASSUMED: what you assumed]` and keep going. The user can overrule it later.
- If the user said to proceed without check-ins, record assumptions, skip the outline approval in section 3, and continue.


## 3. Tier 2: write the contract

Read `references/contract.md` first. It has the template, the rules and the gates.

Write the plan to `plans/<name>.md`, or wherever the repository already keeps plans.
If a plan for this work already exists, ask the user whether to extend it or start a new one.

1. Outline: glossary, parts, scope, limits that must not get worse, the flow as numbered steps including failures, and one end-to-end check. Show it to the user for one approval.
2. Part contracts: for each operation, what it requires, what it ensures (including each named error), and what it changes.
3. Examples: Given/When/Then rows for each operation. They become the tests.
4. Gates: run the checks in `references/contract.md` once and fix gaps in place.
5. Review: section 4.

The rule that matters most: no implementation choices. No language, library, file layout, storage engine or code, unless the user fixed one. Say what can be observed, not how it is done. Those choices are made later, in packets.

Show the user again only if a later step changes something they decided.


## 4. Review the plan

Get one review from a reviewer who didn't write the plan: another model (for example through the codex skill) or a fresh agent. If none is available, do one bounded self-check and tell the user.

Run a second round only if the first found confirmed blockers. A third round needs the user's decision.

Read `references/review.md` before asking for a review or acting on findings. In short: a finding needs evidence, verify it before revising, and fix by replacing text rather than adding it.


## 5. Large plans and parallel work

If the contract has more than three parts or more than one implementer, read `references/parallel.md`. It covers splitting the plan into files, writing packets and running them in parallel.

If several agents will work in one checkout at the same time, also read `references/shared-checkout.md`.


## 6. Implement

- Hand packets to implementers following the delegating-to-subagents skill.
- If an implementer reports the contract is wrong: stop launching packets, fix the contract and its examples in place, re-run the gates on that part, tell the running packets that use it, and log it with the findings.
- Go back to the user only if the fix changes a decision of theirs. A fix is an edit, not a new planning round.

When the work is done and verified, archive or delete the plan and its findings log. Archive means moving them to `plans/archive/`.

- Under version control: archive or delete. Git keeps the history either way.
- No version control: archive only, since deleting would lose it. Tell the user the project isn't under version control.


## 7. Tell the user

Keep it short:

- the tier and why
- decisions you need from them
- assumptions you made
- where the plan is
- review results (confirmed, refuted, deferred), or that no independent review was possible
- the first implementation step
