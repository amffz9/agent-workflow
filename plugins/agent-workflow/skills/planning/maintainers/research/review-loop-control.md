# Controlling LLM reviewer/author loops (researched 2026-10-05)

Tags: [quoted] = short quote + URL; [inferred] = my reasoning. Fetches were summarised by a small model, so quotes are as relayed; verify numbers before citing externally.

## 1. False-positive and hallucination rates

- Rates vary hugely by setup. No source measured design-document review specifically [inferred].
- CodeRabbit field study (July 2026, 31,073 comments, 239 repos): [quoted] "developers rejected 56.3% of agentic reviews, and that false positives were the single largest reason"; 10.3% of false positives traced to "missing visibility into other files". Via https://www.augmentcode.com/guides/ai-code-review-accuracy (vendor guide, secondary; preprint not opened).
- Same guide: Augment benchmark (2025-12-11) 65% precision / 55% recall. CASTLE 2025: GPT-o3 Mini 63% precision / 78% recall vs CodeQL 48% / 29%. Prompt framing swung one model "16.2 to 93.5 percentage points". Older thresholds: [quoted] "a false positive rate above 30% easily causes problems, and that people then ignore the tool" (Coverity, 2010); Tricorder kept it under 10%.
- A 2025 evaluation (search summary only, https://www.researchsquare.com/article/rs-8993044/latest.pdf, not opened): about 50% of generated reviews contain hallucinations; up to 24.8% of correct code blocks drew incorrect suggestions, doubling without a problem description.
- What reduces them: an LLM validating candidate alerts (https://arxiv.org/pdf/2601.18844, 2026-01-28; abstract only, numbers not visible to me). Missing cross-file context is a named cause, so give the reviewer the material it must check against [inferred from the 10.3% figure].
- Anthropic's Opus 5 guide says [quoted] "its additional findings are mostly real issues rather than false positives". Vendor claim, not independent. It sits against the 56.3% field rejection above (different models, tasks, dates): sources disagree.

## 2. Iterative critic loops: convergence and stopping

- Self-correction can hurt: https://arxiv.org/html/2604.22273v2 (2026-05-04), GSM8K n=500. [quoted] improves "only when ECR/EIR > Acc/(1-Acc)". GPT-4o-mini lost 6.2 pp, GPT-5 lost 1.8 pp, o3-mini gained 3.4 pp. Mitigation: [quoted] "Only change your answer if you find a concrete, specific error" turned -6.2 pp into +0.2 pp. Advice: measure error-introduction rate on a calibration set, iterate only if it pays. Math tasks, not review; transfer is [inferred].
- Multi-round review adds noise: https://arxiv.org/pdf/2603.16244 ("More Rounds, More Noise"). Relayed summary: more rounds raised false positives, reviewers raise different claims each round, prefer independent parallel reviews. Details unverified (summary only).
- Non-convergence mechanism, practitioner report: https://github.com/daniel-ospina/agent-infra/issues/1089 (2026-09-15). Plan-review issue counts 37, 39, 35, 54, 52, 46, 45, 45 over 8 cycles. [quoted] "the fixer responds by adding normative text". Proposed: [quoted] "Net line delta per cycle <= 0" and "Exit clean when a cycle produces no P0 and no P1, even if P2s remain." Matches your finding that new issues cluster near prior edits [inferred].
- Other exit rules seen via search (titles only, not opened): https://github.com/mindroom-ai/mindroom/pull/2435 (scope policy); https://github.com/modelcontextprotocol/servers/issues/4931 (stops on first clean round or a round with only out-of-scope findings).
- https://arxiv.org/pdf/2605.12280 (audit convergence): relayed summary mentions plateau-based stopping and corrections that introduced new issues; summary was generic, treat as unverified.
- Disagreement: Anthropic says Opus 5 "catches and fixes its own mistakes well"; the control paper finds strong models (GPT-5) still lose accuracy. Different tasks.

## 3. Reviewer prompt patterns

- Report everything, filter later (Claude 5): [quoted] "If your review prompt says 'only report high-severity issues' or 'be conservative,' the model may follow that instruction literally and report less; ask it to report everything and filter in a separate pass instead." https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-opus-5 (opened, current).
- Same guide advises removing explicit verification steps ("use a subagent to verify") because they "cause over-verification". Tension with adding verifier passes for Claude authors; it says nothing about GPT reviewers.
- Trigger / falsifier fields, "downgrade to NOTE, label unverified pattern match", exact line per finding, no fix for low-confidence findings: found only in third-party blogs, e.g. https://ottermind.ai/blog/gpt-6-coding-review and https://promptessor.com/blog/gpt-6-sol-prompting-guide. I could not open an official OpenAI GPT-6 guide. Treat as practitioner convention.
- Recall cost of "only comment on things that matter": https://github.com/kunchenguid/no-mistakes/issues/598 (2026-07-28); proposes "Report every issue you can substantiate... use the severity field to communicate importance". Their 180 runs showed no visible harm, so effect size is unmeasured.
- "Refuted findings" lists and separating existing-code from new-text defects: no primary source found. Nearest are the scope-policy items and #1089 [inferred].

## 4. "Every finding" vs "only high severity"

- Severity-gated prompts lose recall silently on Claude 5 (guide above); precision rises as a result. No numeric trade-off curve found.
- Reflexion on reviews (CR-Bench, via the Augment guide): recall 27.01% to 32.76%, but signal-to-noise fell 5.11 to 1.95. Extra passes buy recall at a cost in noise.
- Teams filter downstream: severity fields plus a blocking-only gate (no-mistakes `hasBlockingFindings`), advisory streams for recall-tuned reviewers instead of merge gates (Augment guide), P0/P1-only exit (#1089).

## What I would put in a planning skill

1. Reviewer asks for all substantiated findings with severity and confidence; the orchestrator filters. Never "only high severity" in the reviewer prompt. (sourced: Anthropic guide, no-mistakes #598)
2. Each finding carries a quoted text or file:line, the trigger condition, and what would disprove it; no trigger means a NOTE, not a blocker. (inferred; blog-supported)
3. Exit when a round has no P0/P1 blockers; leftover P2s go to a deferred list. (sourced: agent-infra #1089)
4. Cap at 2 rounds per document; a third needs a human decision. (inferred; fits your 3- and 4-round chains)
5. Round 2+ reviewer sees the diff since last round plus prior findings and their resolutions, and labels each new finding "defect in new text" or "pre-existing / out of scope". (inferred, from #1089 mechanism)
6. Author repairs replace or delete rather than add normative text; if the document grew, raise it as a scope finding. (sourced: #1089)
7. Author confirms each blocker by test, quote or code read before fixing, records refuted findings with evidence, and logs confirmed/refuted per round to measure the real false-positive rate. (inferred; verify-first measured on math only)
8. Prefer one independent parallel review to repeated sequential rounds when more assurance is wanted. (sourced: arXiv 2603.16244, summary-level)
