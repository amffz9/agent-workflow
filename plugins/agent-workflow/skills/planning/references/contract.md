# Writing a contract

For Tier 2 plans.
The goal is a document that says what the system does and how its parts talk, so that writing the code is the easy last step.

Stage A is the outline the user approves.
Stage B is the detail, checked by the gates at the end.


## Stage A: outline (show the user)

Write MUST NOT GET WORSE before any part contracts, so the limits shape the design.

```
GLOSSARY
  <Term>: <one-line meaning>
  <Term>: fixed by the user          (a technology or format the user requires)

PARTS
  <Part>: <purpose, one sentence>    (one noun; no part does another's job)

TREE
  <Part>: calls <child parts>

EXISTING PARTS                       (only when changing a running system)
  <Part>: unchanged
  <Part>: changed: <op> now ensures X, will ensure Y

OUT OF SCOPE
  <what this plan does not change>

MUST NOT GET WORSE
  <a checkable limit on cost, quality, size, speed or resources, from the user's goal>

FLOW
  1. <Part A> calls <Part B>.<op> with <inputs>
  2. On <named error>, <Part A> ...
  (include failure and timeout branches)

END-TO-END CHECK
  <the one runnable scenario that proves the flow>

IRREVERSIBLE STEPS                   (if any)
  <step>: <safeguard: backup, dry run, check before and after, who gives the go-ahead>

NEEDS CLARIFICATION                  (only the user can settle these; they block)
  [NEEDS CLARIFICATION: ...]

ASSUMPTIONS                          (everything else; these don't block)
  [ASSUMED: ...]
```


## Stage B: one block per part

```
PART: <Name>
Purpose:     one sentence
Kind:        core | boundary
Owns:        data and decisions only this part may change
Data:        <Type>: fields with types, which are optional, units, valid values,
             and what makes two values equal
Never does:  jobs that belong to other parts

Offers:
  op <name>(<input: type>) -> <result | named error>
    Requires:  what the caller must guarantee
    Ensures:   the observable result, including each named error and when it happens
    Effects:   what changes that others can see
    Order:     must come after <X>; safe to repeat? yes/no

Needs:       operations this part uses from other parts or the outside world,
             each with Requires and Ensures
Emits:       events or messages, their fields, and when
States:      the states, and moves written as  state --event[condition]--> state
             (mark the final states)
Invariants:  statements that are always true and can be checked from outside

Examples:
  Given <state>  When <op with values>  Then <result, new state, events>
```

Boundary parts: facts about the platform they wrap (its quirks, limits, names) appear only in that part's block and its packet, never in core parts. A core part says what it needs in plain terms; the boundary part promises that.

Mostly-UI changes: a part is a screen or component. Offers are user actions (focus, key, tap) and the visible result. States are visible states. Examples read "Given <screen> When <input> Then <what is visible, where focus is>", with a reference image where words aren't enough. Leave out sections that don't apply. Shared styling is its own early packet, done before the screen packets.


## Keep implementation out

- No language names, libraries, file or module layout, function bodies, storage engines or class hierarchies.
- Exception: something the user requires. Name it once in the glossary as "fixed by the user", then use that term.
- Test: if a sentence would change when the language changes, rewrite it.
- Types are domain types (`Timestamp`, `ChannelId`, `Recording`), not language types. Define each once.
- Describe behaviour you can observe. If a rule is needed, state its effect ("the earliest unfinished recording is chosen"), never an algorithm.
- Every name points somewhere: parts to PARTS, operations to Offers or Needs, terms and types to GLOSSARY or Data.


## Examples and tests

- Write examples as a table with concrete values, so each row becomes one test.
- Each operation needs at least: one normal case, one per named error, and the edge cases that apply (empty, first, last, repeated, concurrent, invalid versus unreachable, live versus finished).
- The example rows are the required tests. Don't require more tests or count them; tests an agent writes for its own code tend to mirror the code.
- Hold back some rows and the end-to-end check from the implementer, and run them yourself afterwards. Agents who see every test build to the tests. If you are the only agent, say the checks weren't hidden.
- For high-stakes parts, judge tests by mutation testing or negative controls, not coverage.
- If only hardware or a manual check can settle something, name that check.


## Gates

Run these once, before the review. Whoever runs the gates is not the reviewer.

1. Cross-reference: every part in the flow exists, every Need has a matching Offer, every named error is produced and handled, every non-final state has an exit, every type is defined.
2. Walk-through: run the flow by hand on three scenarios using only the document. Any step that needs an unwritten fact is a gap.
3. Goal trace: each sentence of the user's goal maps to a guarantee, and for each you can say how the user would still notice if it failed.
4. Platform facts: check each boundary part's facts first-hand (read the source or docs, or run a small experiment) before anything is built on them.
5. Question pass (split plans only): a cheaper agent that has seen only the contract lists the behaviour questions it would need answered. Questions about language, files, tooling or storage don't count; packets answer them. Ready means no behaviour questions remain.

For a single-file plan, skip the question pass. Instead, have the reviewer check the outline against the real code before you write the part contracts. A document-only question pass on a small plan produces mostly noise.

If a gate finds a gap, edit the contract in place and re-check only what you edited. That is not a new planning round.


## Optional tools

- Exact message formats between separately built parts: an interface definition language (OpenAPI, protobuf). These leave out behaviour, so keep the Ensures text too.
- Concurrency-heavy parts: a formal spec (TLA+), only with a human reviewing it.
