# Reviewing a plan

Review loops run forever when each fix adds text the next reviewer attacks, and when claims can't be checked.
These rules keep the loop short.


## Asking for a review

- Give the reviewer the plan plus the source files and contracts its claims will touch. Missing context causes false findings.
- Ask for every finding it can back up, each with severity and confidence. Filter afterwards. Telling a reviewer "only high severity" makes it drop real problems.
- Ask it to label each finding with origin (added by the last revision, or already there) and scope (inside or outside this change).
- From round two on, pass along the refuted findings and earlier fixes as evidence, not as a ban. The reviewer may reopen one if the text or code it relied on changed.
- If you want more assurance, add one more reviewer in parallel, not another round.


## Severity

- blocker: confirmed, and breaks correctness or a stated requirement.
- should-fix: confirmed, but doesn't break either. Goes on the deferred list.
- note: no evidence. Never blocks.


## What counts as a finding

A finding quotes the line (or gives `file:line`), says what triggers the problem, and says what would disprove it.

- A problem in the plan text needs only that.
- A claimed bug in existing code also needs a failing test or script against the current code.
- If running one is unsafe or impossible: a concrete trace through the source, plus the manual or hardware check that would settle it. You run or confirm that check before the finding can block.
- Anything without this evidence is a note.

A reviewer asked to find gaps usually finds some even in sound work. Act only on confirmed blockers.


## Verify before revising

- For each blocker, run its repro or read the cited code. Confirm it fails for the reason given.
- When you accept a fix for a disputed bug, write the failing check first, have the git owner commit it, and don't change it without review.
- Record each refuted finding with its evidence and the plan revision it applied to.


## Fixing

- A defect in text the last revision added: replace or delete that text. Don't add rules on top.
- Plan growth that confirmed findings didn't require is itself a finding.
- Defects that were already there and are in scope stay blockers. Out-of-scope ones go to the backlog.


## When to stop

- Stop when a round has no confirmed blocker. Anything left goes on the deferred list.
- At most two rounds per document. A third needs the user's decision.


## Findings log

Keep it next to the plan: `plans/<name>.findings.md`, or `plans/<name>/findings.md` for a split plan.
It stops refuted claims from coming back and shows how many findings were real.

```
# Findings: <plan name>   (round cap: 2)

F1  round 1  blocker     confirmed
    claim:    <quote or file:line>
    trigger:  <input sequence, or path to failing test>
    evidence: test fails for the stated reason
    result:   fixed in <section or commit>

F2  round 1  blocker     refuted
    claim:    ...
    trigger:  ...
    evidence: counter-test passes (applies to revision R1)
    result:   none

F3  round 1  should-fix  deferred
    claim:    ...
    trigger:  none given
    evidence: pattern match only
    result:   backlog

Round 1: confirmed 1, refuted 1, deferred 1.
Plan size before / after: <lines> / <lines>
```

Status is one of: confirmed, refuted, deferred, note.
