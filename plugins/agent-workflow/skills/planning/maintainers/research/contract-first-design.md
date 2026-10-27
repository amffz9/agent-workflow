# Contract-first, implementation-free design with LLM agents (researched 2026-10-05)

Tags: [quoted] = short quote + URL; [inferred] = my synthesis. Several fetches went through a summarising model, so quotes from PDFs are paraphrase-grade.

## 1. Established techniques

| Technique | Expresses | Leaves out | Worth it when |
|---|---|---|---|
| Design by contract (Meyer/Eiffel) | Per operation: caller obligations (pre), supplier promises (post), always-true facts (invariants). [quoted] "precondition ... must be satisfied before a routine executes"; invariant "must hold for all instances ... at all times" (eiffel.com/values/design-by-contract/introduction/, undated) | Call order across parts; flow | Every boundary between parts. Cheapest high-value tool. |
| Ports and adapters (Cockburn, 2005) | The conversations the core has with the outside. [quoted] "The protocol for a port is given by the purpose of the conversation" (alistair.cockburn.us/hexagonal-architecture/) | Technology behind each port | Anything touching tuner, disk, clients, clock. |
| IDL as pure contract (OpenAPI, protobuf) | Exact message shapes, names, errors | Behaviour, ordering, field semantics | When parts are built separately. Pair with prose for semantics. [inferred] |
| State machines / sequence descriptions | States, allowed transitions, who calls whom in what order | Data detail | Lifecycles (recording: scheduled, running, done, failed). [inferred] |
| Given/When/Then | Concrete behaviour examples. [quoted] "specifying a system's behavior using SpecificationByExample" (martinfowler.com/bliki/GivenWhenThen.html, 2013-08-21) | General rules; unlisted cases | Acceptance and edge cases; examples become tests. |
| TLA+/PlusCal | Precise, model-checkable design. [quoted] AWS: "exhaustively testable pseudocode" (lamport.azurewebsites.net/tla/formal-methods-amazon.pdf, 2014) | Performance, real network behaviour | Concurrency, scheduler races. Heavy; LLMs are weak at it (section 3). |
| Alloy | Structural/relational models checked on small instances. [quoted] "Most bugs have small counterexamples" (Jackson, Software Abstractions, via search summary) | Time and flow | Data-model invariants. Optional. |
| Structured pseudocode | Control flow at decision level | Syntax, libraries | Flow only, at step level; bodies are where leakage starts. [inferred] |

Evidence is strongest for contracts, ports and examples; TLA+/Alloy are proven by experts, not by agents.

## 2. Minimal contract template

Elements come from Spec Kit (WHAT not HOW, NEEDS CLARIFICATION), Meyer (pre/post/invariant), Cockburn (ports), BDD (examples). The assembly is [inferred].

```
PART: <Name>            (one noun; use these names everywhere)
Purpose: one sentence, what it is responsible for. Nothing else.
Owns: data/decisions only this part may change.
Never does: responsibilities that belong to other parts.
Terms: <glossary entries used by this part>
Offers (operations):
  op <name>(<input: domain type>) -> <result | named error>
    Requires: <condition the caller must guarantee>
    Ensures:  <observable result, incl. each named error and when>
    Effects:  <what changes, visible outside this part>
    Order/Timing: <must come after X; idempotent? y/n>
Needs (ports): <name>: what it must provide, as ops with Requires/Ensures
Emits: <events/messages, payload fields, when>
States: <state list; transitions as "state --event[guard]--> state">
Invariants: <always-true statements>
Examples:
  Given <state> When <op with values> Then <result/state/events>
  (at least: one normal, one per named error, one boundary)
Open questions: [NEEDS CLARIFICATION: ...]
FLOW (document-level, once): numbered steps "Part A calls B.op -> ...",
  including failure branches.
FORBIDDEN in this document: language, library, file/module layout,
  function bodies, storage engine, algorithms beyond a stated observable rule.
```
Leak control: types are domain types ("Timestamp", "ChannelId"), not language types; behaviour is observable only; "how" appears only as a named rule with its observable effect. [inferred]

## 3. LLM failure modes and counters

- Leakage into abstract specs: LLMs "generate specifications resembling the concrete code implementation" [paraphrase of arXiv 2606.26490, VeriFast study, 2026-06-26; PDF unreadable, summary only]. Evidence is for formal specs; applying it to prose specs is [inferred].
- Overspecifying and drift: a search summary of CodeSpecBench (arXiv 2604.12268) reports LLMs "overspecify" and drift over iterations. Not opened; thin evidence.
- Abstraction-level confusion, even for humans using SDD tools: [quoted] Böckeler: "I frequently got confused when to stay on the functional level"; agents "ultimately not follow all the instructions"; docs "very verbose and tedious to review" (martinfowler.com/articles/exploring-gen-ai/sdd-3-tools.html, 2025-10-15). This contradicts the vendor pitch of Spec Kit; it is one author's trials.
- Wrong TLA+: syntax errors, incomplete specs (arXiv 2606.05792, 2026-06-05; summary only). Do not have agents write TLA+ unaided. [inferred]
- Invented interfaces / inconsistent names: no study on spec documents found. Tool-use work reports hallucinated tools and arguments (arXiv 2609.19425, abstract only). Spec Kit's /speckit.analyze targets it: it flags "terminology drift" and plan entities missing from the spec (github.github.io/spec-kit/reference/agentic-sdd.html, via search summary; unopened).
- Counters that exist: Spec Kit template [quoted] avoid "HOW to implement (no tech stack, APIs, code structure)", mark gaps "[NEEDS CLARIFICATION: specific question]", and templates "constrain the LLM's output in productive ways" (github.com/github/spec-kit/blob/main/spec-driven.md).
- Claude guide: [quoted] "Claude responds well to clear, explicit instructions"; Opus 4.5/4.6 overengineer unless told to keep solutions minimal (platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices, current; second point from search summary). Say what to produce (allowed vocabulary), not only a ban list. [inferred]

## 4. Verifying a contract before coding

- Cross-check pass by a separate agent: every name in FLOW exists as a PART; every Needs has an Offers; every named error is produced and handled. Same idea as /speckit.analyze. [inferred]
- Examples that run against any implementation: [quoted] Pact is "contract by example", each case a "single concrete request/response pair" (docs.pact.io and search summary). Write Given/When/Then as a language-neutral table; a thin harness runs it against the implementation or a fake adapter. [inferred]
- Hand walk-through of FLOW on three scenarios using only the document; any step needing an unwritten fact is a gap. [inferred]
- Implementability review: a fresh agent given only the contract lists the questions it would need answered; zero questions means ready. [inferred]
- Checklist: no technology words; every op has Requires/Ensures; every state has an exit; invariants checkable from outside. [inferred]
- Optional: model-check the one or two concurrency-heavy parts in PlusCal. [inferred]

## Gaps
No source found measuring how well agents hold the WHAT/HOW line in plain-text contracts; all leakage evidence comes from formal-spec work or SDD-tool experience.

## What I would put in a planning skill
1. Two stages: FLOW plus part list first, user approves, then per-part contracts. (inferred)
2. Fixed template with a FORBIDDEN list and domain-only types. (sourced: Spec Kit WHAT/HOW; template shape inferred)
3. Glossary written first; every later name must come from it. (inferred)
4. Pre/post/invariant per operation, with named errors. (sourced: Meyer/Eiffel)
5. A port for everything external, with Needs written as contracts. (sourced: Cockburn)
6. Given/When/Then per operation: normal, error, boundary. (sourced: Fowler/BDD)
7. Unknowns become [NEEDS CLARIFICATION] questions, never guesses. (sourced: Spec Kit)
8. Gate before any code: cross-reference check plus fresh-agent question pass. (sourced in part: speckit.analyze; fresh-agent pass inferred)
