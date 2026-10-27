# Evidence behind the planning rules

Gathered 2026-10-05 by four Sonnet research agents; full reports with URLs are in `research/`. Most fetches went through a summarising model and several sources were seen only as search snippets or abstracts, so verify any number before citing it outside this skill. No source measured plan depth against rework for Claude Code or Codex, none measured false findings in design-document review, and none measured how well agents hold the what/how line in plain-text contracts. Where a rule rests on the author's reasoning, it is marked inferred.

Reviewed independently by Fable 5.1 and GPT-6 Astra on 2026-10-05 (72 findings in all, most overlapping); one combined round of fixes was applied, including the labels below.

| Rule in the skill | Basis | Status |
|---|---|---|
| Skip planning when the diff fits in one sentence; plan when approach is uncertain, multi-file or unfamiliar | Anthropic Claude Code best practices; OpenAI Codex guide says skip the easiest ~25% | sourced |
| Big-work spec names interfaces, states out-of-scope, ends with an end-to-end check | Anthropic best practices (which also names files; this skill moves files to packets by design) | sourced, adapted |
| Planning helps weaker models more; for stronger models it mostly cuts cost | arXiv 2609.20804 (open models, in-loop plan tool, no rework measure) | sourced, narrow |
| Cheaper implementers may need a more explicit contract | Extrapolated from the study above to written contracts | inferred |
| Three tiers, review-round counts per tier, irreversible-simple as Tier 1 plus safeguard | Synthesis of the above | inferred |
| Try cheap attempts when undo is free; checkpoints miss side effects | Anthropic best practices (advice, not measured) | sourced |
| No time estimates; size by risk | Author's instruction, supported by session data (plan agents ran 92-169 min unpredictably) | author's rule |
| Contract techniques: requires/ensures/invariants, ports, Given/When/Then, NEEDS CLARIFICATION markers, WHAT-not-HOW | Meyer/Eiffel, Cockburn, Fowler/BDD, GitHub Spec Kit | sourced |
| State machines for lifecycles, the assembled template, forbidden-vocabulary list, two-stage approval, glossary-first | Combination of the above; the state-machine recommendation is marked inferred in the research | inferred |
| Gates: cross-reference check, cheaper-agent question pass, walk-through | Spec Kit's analyze command idea; rest | mostly inferred |
| Reviewers report everything with severity; filter afterwards | Anthropic Opus 5 prompting guide | sourced |
| Missing cross-file context gives false positives | One field study: about 10.3% of false positives (secondary source); no ranking of causes | sourced, weak |
| Findings need trigger and falsifier; no trigger means NOTE | Third-party blogs only | inferred |
| Exit when a round has no top-severity finding; fixer replaces or deletes instead of adding text | A practitioner issue report (agent-infra #1089) that proposes this; not an observed result | proposed in one issue, anecdotal |
| Cap at two rounds; third needs a human | Fits the observed 4-round non-convergence and 3-round convergence in the author's project | inferred |
| Verify each blocker and log refuted findings | Verify-first instruction removed self-correction loss in a math study | inferred for review |
| Failing test for disputed bugs in existing code; red check | SWT-Bench (reproduction tests double precision as a filter) | sourced |
| Don't mandate tests for every task | arXiv 2602.07900: forcing more agent tests did not change SWE-bench outcomes | sourced |
| Judge tests by mutation, not coverage | MUTGEN (100% coverage, 4% mutation score) | sourced, small samples |
| Agents build to tests they are given | arXiv 2606.28430 | observed, small samples |
| Hold back some acceptance checks from the implementer | Mitigation for the two rows above; supported by implication only | inferred |
| One parallel independent review instead of more rounds | arXiv 2603.16244, summary-level only | weak |
| File split, contract tree, parallel implementation against contracts, bottom-up verification phase, packets | The author's design plus the delegating skill's parallelism rules and the contract-first literature; no source measured it | inferred |
| Fork when several short jobs share a large context; fresh agent with a digest for long or narrow jobs | One measurement in the author's project (2026-10-05): forks inherited full context and reused the parent's cache (first call ~129.7k read, 627 written). Cost rule derived from it | measured once, small; break-even is an estimate |
| Never fork for independent review; forks cannot be downshifted | Tool behaviour (fork runs on the parent's model, shares its context) | documented behaviour, reasoning inferred |
| One owner for git and heavy commands when parallel writers or heavy resources exist; command-queue agent pattern | Author's experience (agents collide, overloaded machine); measured overlap in the author's project was modest: peak 2 agents, no cross-agent git writes in three sessions | inferred, no external source |
| Boundary parts wrap uncontrolled platforms; platform facts checked first-hand; must-not-get-worse invariants; goal trace; edge-case list; review the outline against the code first; skip the document-only question pass on small plans | One planning run in the author's project (2026-10-05): about 7 of 15 review findings were platform behaviour written into core contracts, about 8 were unlisted edge cases, unwritten non-functional limits or the plan author's logic slips; the document-only gate gave 78 mostly low-value items; ports and adapters from the contract-first research | inferred from one run |

## Measurements moved out of the agent-facing files (2026-10-27)

- Splitting large plans: in one session a single 1,000-line plan was read by six agents and re-read in 22 slices by one of them.
- Forks: a Sonnet 5.5 parent holding ~130k tokens spawned three forks; each first call read ~129.7k tokens from cache and wrote 627 (~$0.03). A fork pays its full context on every call, so break-even against a fresh agent was estimated at around eight calls. Not tested: long fork tasks, a compacted parent, an expired cache, more than two forks at once.
- Shared checkout: in the author's project's three largest recent sessions, at most two agents ran heavy commands at once (~9 minutes of test overlap) and agents never overlapped on state-changing git.

## Rules added or settled in the 2026-10-27 restructure (all inferred)

| Rule | Reason |
|---|---|
| Single-file plans live at `plans/<name>.md` unless the repo has its own place | Location was undefined for single-file plans |
| Severity scale: blocker / should-fix / note | "Top severity", "blocker" and "lower severity" were used without a definition |
| "Proceed without check-ins" also skips the outline approval | The two rules conflicted |
| "Small plan" (skip the question pass) means a single-file plan | "Small" was undefined |
| Use a full clone, never a worktree, for isolation | Two files disagreed; the queue-agent text allowed worktrees |
| Name the reviewer: another model (e.g. codex skill) or a fresh agent | "Independent review" never said who |
| Finished plans are archived (`plans/archive/`) or deleted; archive only without version control | Author's rule, 2026-10-27 |
| An existing plan for the same work: ask the user whether to extend it or start over | Author's rule, 2026-10-27 |

## Counter-evidence to keep in mind

- Anthropic says Opus 5 finds mostly real issues; a field study of agentic code review reports 56.3% of comments rejected. Different models and tasks; measure the ledger counts in your own runs.
- Self-correction can reduce accuracy for strong models on some tasks, which is why the skill requires evidence before revising.
- Spec-driven tools claim more up-front specification reduces drift; the harness study and Anthropic's "try it, then rewind" advice suggest planning often costs more than it returns for capable models and reversible work. The tiers exist to split these cases.
